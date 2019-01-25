#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;

binmode( STDIN,  ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );

our ($Old_Pwd);
our @Old_ARGV = @ARGV;

use Cwd;
use FindBin;
use Data::Dumper;

BEGIN {
    $Old_Pwd = Cwd::cwd();
    chdir "$FindBin::RealBin/";
}

use lib 'lib';
use Proc::PID::File;
die "$0 already running\n"
    if Proc::PID::File->running( dir => '.run' );

use ES::Util qw(
    run $Opts
    build_chunked build_single build_pdf
    git_creds
    proc_man
    sha_for
    timestamp
    write_html_redirect
);

use Getopt::Long;
use YAML qw(LoadFile);
use Path::Class qw(dir file);
use Browser::Open qw(open_browser);

use ES::BranchTracker();
use ES::Repo();
use ES::Book();
use ES::Toc();
use ES::LinkCheck();
use ES::Template();

GetOptions(
    $Opts,    #
    'all', 'push', 'update!', 'target_repo=s', 'reference=s', 'rely_on_ssh_auth', 'rebuild', 'no_fetch', #
    'single',  'pdf',     'doc=s',           'out=s',  'toc', 'chunk=i',
    'open',    'skiplinkcheck', 'linkcheckonly', 'staging', 'procs=i',         'user=s', 'lang=s',
    'lenient', 'verbose', 'reload_template', 'resource=s@', 'asciidoctor'
) || exit usage();

our $Conf = LoadFile('conf.yaml');

checkout_staging_or_master();
update_self() if $Opts->{update};
init_env();

my $template_urls
    = $Conf->{template}{branch}{ $Opts->{staging} ? 'staging' : 'default' };

$Opts->{template} = ES::Template->new(
    %{ $Conf->{template} },
    %$template_urls,
    lenient  => $Opts->{lenient},
    force    => $Opts->{reload_template},
    abs_urls => $Opts->{doc}
);

$Opts->{doc}       ? build_local( $Opts->{doc} )
    : $Opts->{all} ? build_all()
    :                usage();

#===================================
sub build_local {
#===================================
    my $doc = shift;

    my $index = file($doc)->absolute($Old_Pwd);
    die "File <$doc> doesn't exist" unless -f $index;

    return build_local_pdf($index) if $Opts->{pdf};

    say "Building HTML from $doc";

    my $dir = dir( $Opts->{out} || 'html_docs' )->absolute($Old_Pwd);
    # NOCOMMIT in docker we can't clean this up for some reason.

    $Opts->{resource}
        = [ map { dir($_)->absolute($Old_Pwd) } @{ $Opts->{resource} || [] } ];

    _guess_opts_from_file($index);

    if ( $Opts->{single} ) {
        $dir->rmtree;
        $dir->mkpath;
        build_single( $index, $dir, %$Opts );
    }
    else {
        build_chunked( $index, $dir, %$Opts );
    }

    say "Done";

    my $html = $dir->file('index.html');

    if ( $Opts->{open} ) {
        if ( my $pid = fork ) {
            # parent
            $SIG{INT} = sub {
                kill -9, $pid;
            };
            if ( $Opts->{open} ) {
                sleep 1;
                say "Opening: " . $html;
                say "Press Ctrl-C to exit the web server";
                open_browser('http://localhost:8000/index.html');
            }

            wait;
            say "\nExiting";
            exit;
        }
        else {
            if ( _running_in_docker() ) {
                # We use nginx to serve files instead of the python built in web server
                # when we're running inside docker because the python web server performs
                # badly there. nginx is fine.
                open(my $nginx_conf, '>', '/tmp/docs.conf') or dir("Couldn't write nginx conf to /tmp/docs/.conf");
                print $nginx_conf <<"CONF";
daemon off;
error_log /dev/stdout crit;

events {
  worker_connections 64;
}

http {
  log_format short '[\$time_local] "\$request" \$status';
  access_log /dev/stdout short;
  server {
    listen 8000;
    location / {
      root $dir;
      add_header 'Access-Control-Allow-Origin' '*';
      if (\$request_method = 'OPTIONS') {
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
        add_header 'Access-Control-Allow-Headers' 'kbn-xsrf-token';
      }
    }
    types {
      text/html  html;
      application/javascript  js;
      text/css   css;
    }
  }
}
CONF
                dir( '/run/nginx' )->mkpath;
                close STDIN;
                open( STDIN, "</dev/null" );
                chdir $dir;
                exec( 'nginx', '-c', '/tmp/docs.conf' );
            } else {
                my $http = dir( 'resources', 'http.py' )->absolute;
                close STDIN;
                open( STDIN, "</dev/null" );
                chdir $dir;
                exec( $http '8000' );
            }
        }
    }
    else {
        say "See: $html";
    }
}

#===================================
sub _running_in_docker {
#===================================
    # return 0;
    my $root_cgroup = dir('/proc/1/cgroup');
    return 0 unless ( -e $root_cgroup );
    open(my $root_cgroup_file, $root_cgroup);
    return grep {/docker/} <$root_cgroup_file>;
}

#===================================
sub _guess_opts_from_file {
#===================================
    my $index = shift;

    my $dir = $index->parent;
    while ($dir ne '/') {
        $dir = $dir->parent;
        my $git_dir = $dir->subdir('.git');
        if (-d $git_dir) {
            $Opts->{root_dir} = $dir;
            local $ENV{GIT_DIR} = $git_dir;
            my $remotes = eval { run qw(git remote -v) } || '';
            if ($remotes !~ /\s+(\S+[\/:]elastic\/\S+)/) {
                say "Couldn't find edit url because there isn't an Elastic clone";
                say "$remotes";
                return;
            }
            my $remote = $1;
            my $branch = eval {run qw(git rev-parse --abbrev-ref HEAD) } || 'master';
            $Opts->{edit_url} = ES::Repo::edit_url_for_url_and_branch($remote, $branch);
            return;
        }
    }
    say "Couldn't find edit url because the document doesn't look like it is in git";
    $Opts->{root_dir} = $index->parent;
}

#===================================
sub build_local_pdf {
#===================================
    my $index = shift;
    my $dir = dir( $Opts->{out} || './' )->absolute($Old_Pwd);

    build_pdf( $index, $dir, %$Opts );
    say "Done";
    my $pdf = $index->basename;
    $pdf =~ s/\.[^.]+$/.pdf/;
    $pdf = $dir->file($pdf);
    if ( $Opts->{open} ) {
        say "Opening: $pdf";
        open_browser($pdf);
    }
    else {
        say "See: $pdf";
    }
}
#===================================
sub build_all {
#===================================
    unless ( $Opts->{rely_on_ssh_auth} ) {
        say "Checking GitHub username and password (or auth token for multi-factor auth)";

        ensure_creds_cache_enabled() || enable_creds_cache() || exit(1);
        check_github_authed();
    }

    my ($repos_dir, $temp_dir, $target_repo, $target_repo_checkout) = init_repos();

    my $build_dir = $Conf->{paths}{build}
        or die "Missing <paths.build> in config";
    if ( $target_repo ) {
        $build_dir = dir("$target_repo_checkout/$build_dir");
    } else {
        $build_dir = dir($build_dir);
    }
    $build_dir->mkpath;

    my $contents = $Conf->{contents}
        or die "Missing <contents> configuration section";

    my $toc = ES::Toc->new( $Conf->{contents_title} || 'Guide' );

    if ( $Opts->{linkcheckonly} ){
        say "Skipping documentation builds."
    }
    else {
        build_entries( $build_dir, $temp_dir, $toc, @$contents );

        say "Writing main TOC";
        $toc->write( $build_dir, 0 );

        say "Writing extra HTML redirects";
        for ( @{ $Conf->{redirects} } ) {
            write_html_redirect( $build_dir->subdir( $_->{prefix} ),
                    $_->{redirect} );
        }
    }
    if ( $Opts->{skiplinkcheck} ) {
        say "Skipped Checking links";
    }
    else {
        say "Checking links";
        check_links($build_dir);
    }
    push_changes($build_dir, $target_repo, $target_repo_checkout) if $Opts->{push};

    $temp_dir->rmtree;
}

#===================================
sub check_links {
#===================================
    my $build_dir    = shift;
    my $link_checker = ES::LinkCheck->new($build_dir);

    $link_checker->check;

    check_kibana_links( $build_dir, $link_checker );
    if ( $link_checker->has_bad ) {
        say $link_checker->report;
    }
    else {
        die $link_checker->report;
    }

}

#===================================
sub check_kibana_links {
#===================================
    my $build_dir    = shift;
    my $link_checker = shift;
    my $branch;

    say "Checking Kibana links";

# ${baseUrl}guide/en/elasticsearch/reference/${urlVersion}/modules-scripting-expression.html
# ${ELASTIC_WEBSITE_URL}guide/en/beats/filebeat/${DOC_LINK_VERSION}
# ${ELASTIC_DOCS}search-aggregations-bucket-datehistogram-aggregation.html

    my $extractor = sub {
        my $contents = shift;
        return sub {
            while ( $contents =~ m!`(\$\{(?:baseUrl|ELASTIC_.+)\}[^`]+)`!g ) {
                my $path = $1;
                $path =~ s/\$\{(?:DOC_LINK_VERSION|urlVersion)\}/$branch/;
                $path
                    =~ s!\$\{ELASTIC_DOCS\}!en/elasticsearch/reference/$branch/!
                    || $path =~ s!\$\{(?:baseUrl|ELASTIC_WEBSITE_URL)\}guide/!!;
                return ( split /#/, $path );
            }
            return;
        };

    };

    my $src_path = 'src/ui/public/documentation_links/documentation_links';
    my $repo     = ES::Repo->get_repo('kibana');

    my @branches = sort map { $_->basename }
        grep { $_->is_dir } $build_dir->subdir('en/kibana')->children;

    for (@branches) {
        $branch = $_;
        next if $branch eq 'current' || $branch =~ /^\d/ && $branch lt 5;
        say "  Branch $branch";
        my $source = eval {
            $repo->show_file( $branch, $src_path . ".js" )    # javascript
        } || $repo->show_file( $branch, $src_path . ".ts" );    # or typescript

        $link_checker->check_source( $source, $extractor,
            "Kibana [$branch]: $src_path" );
    }
}

#===================================
sub build_entries {
#===================================
    my ( $build, $temp_dir, $toc, @entries ) = @_;

    while ( my $entry = shift @entries ) {
        my $title = $entry->{title}
            or die "Missing title for entry: " . Dumper($entry);

        if ( my $sections = $entry->{sections} ) {
            my $base_dir = $entry->{base_dir} || '';
            my $section_toc = build_entries(
                $build->subdir($base_dir), $temp_dir,
                ES::Toc->new( $title, $entry->{lang} ), @$sections
            );
            if ($base_dir) {
                $section_toc->write( $build->subdir($base_dir) );
                $toc->add_entry(
                    {   title => $title,
                        url   => $base_dir . '/index.html'
                    }
                );
            }
            else {
                $toc->add_entry($section_toc);
            }
            next;
        }
        my $book = ES::Book->new(
            dir      => $build,
            template => $Opts->{template},
            temp_dir => $temp_dir,
            %$entry
        );
        $toc->add_entry( $book->build($Opts->{rebuild}) );
    }

    return $toc;
}

#===================================
sub build_sitemap {
#===================================
    my ($dir) = @_;
    my $sitemap = $dir->file('sitemap.xml');

    say "Building sitemap: $sitemap";
    open my $fh, '>', $sitemap or die "Couldn't create $sitemap: $!";
    say $fh <<SITEMAP_START;
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
SITEMAP_START

    my $date     = timestamp();
    my $add_link = sub {
        my $file = shift;
        my $url  = 'https://www.elastic.co/guide/' . $file->relative($dir);
        say $fh <<ENTRY;
<url>
    <loc>$url</loc>
    <lastmod>$date</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.5</priority>
</url>
ENTRY

    };

    $dir->recurse(
        callback => sub {
            my $item = shift;

            return unless $item->is_dir && $item->basename eq 'current';
            if ( -e $item->file('toc.html') ) {
                my $content = $item->file('toc.html')
                    ->slurp( iomode => '<:encoding(UTF-8)' );
                $add_link->( $item->file($_) )
                    for ( $content =~ /href="([^"]+)"/g );
            }
            elsif ( -e $item->file('index.html') ) {
                $add_link->( $item->file('index.html') );
            }
            return $item->PRUNE;
        }
    );

    say $fh "</urlset>";
    close $fh or die "Couldn't close $sitemap: $!"

}

#===================================
sub init_repos {
#===================================
    say "Updating repositories";

    my $repos_dir = $Conf->{paths}{repos}
        or die "Missing <paths.repos> in config";

    $repos_dir = dir($repos_dir)->absolute;
    $repos_dir->mkpath;

    my %child_dirs = map { $_ => 1 } $repos_dir->children;

    my $temp_dir = $repos_dir->subdir('.temp');
    $temp_dir->rmtree;
    $temp_dir->mkpath;
    delete $child_dirs{ $temp_dir->absolute };

    my $conf = $Conf->{repos}
        or die "Missing <repos> in config";

    my @repo_names = sort keys %$conf;

    my $tracker_path = $Conf->{paths}{branch_tracker}
        or die "Missing <paths.branch_tracker> in config";

    my $reference_dir = dir($Opts->{reference});
    if ( $reference_dir ) {
        $reference_dir = $reference_dir->absolute;
        die "Missing reference directory $reference_dir" unless -e $reference_dir;
    }

    my $target_repo = 0;
    my $target_repo_checkout = 0;
    if ( $Opts->{target_repo} ) {
        # If we have a target repo check it out before the other repos so that
        # we can use the tracker file in that repo.
        $target_repo = ES::Repo->new(
            name      => 'target_repo',
            dir       => $repos_dir,
            user      => $Opts->{user},
            url       => $Opts->{target_repo},
            reference => $reference_dir,
            # intentionally not passing the tracker because we don't want to use it
        );
        delete $child_dirs{ $target_repo->git_dir->absolute };
        $target_repo_checkout = "$temp_dir/target_repo";
        $tracker_path = "$target_repo_checkout/$tracker_path";
        eval {
            $target_repo->update_from_remote();
            say " - Checking out: target_repo";
            $target_repo->checkout_to($target_repo_checkout);
            1;
        } or do {
            # If creds are invalid, explicitly reject them to try to clear the cache
            my $error = $@;
            if ( $error =~ /Invalid username or password/ ) {
                revoke_github_creds();
            }
            die $error;
        };
    }

    # check out all remaining repos in parallel
    my $tracker = ES::BranchTracker->new( file($tracker_path), @repo_names );
    my $pm = proc_man( $Opts->{procs} * 3 );
    for my $name (@repo_names) {
        my $url = $conf->{$name};
        $url =~ s|https://([^/]+)/|git\@$1:| if ( $Opts->{rely_on_ssh_auth} );
        my $repo = ES::Repo->new(
            name      => $name,
            dir       => $repos_dir,
            tracker   => $tracker,
            user      => $Opts->{user},
            url       => $url,
            reference => $reference_dir,
        );
        delete $child_dirs{ $repo->git_dir->absolute };

        if ( $Opts->{linkcheckonly} ){
            say "Skipping fetching repo $name."
        }
        else {
            $pm->start($name) and next;
            eval {
                $repo->update_from_remote() unless $Opts->{no_fetch};
                1;
            } or do {
                # If creds are invalid, explicitly reject them to try to clear the cache
                my $error = $@;
                if ( $error =~ /Invalid username or password/ ) {
                    revoke_github_creds();
                }
                die $error;
            };
            $pm->finish;
        }
    }
    $pm->wait_all_children;

    for ( keys %child_dirs ) {
        my $dir = dir($_);
        next unless -d $dir;
        say "Removing old repo <" . $dir->basename . ">";
        $dir->rmtree;
    }
    return ($repos_dir, $temp_dir, $target_repo, $target_repo_checkout);
}

#===================================
sub push_changes {
#===================================
    my ($build_dir, $target_repo, $target_repo_checkout) = @_;

    local $ENV{GIT_WORK_TREE} = $target_repo_checkout if $target_repo;
    local $ENV{GIT_DIR} = $ENV{GIT_WORK_TREE} . '/.git' if $target_repo;

    say 'Building revision.txt';
    $build_dir->file('revision.txt')
        ->spew( iomode => '>:utf8', ES::Repo->all_repo_branches );

    say 'Preparing commit';
    run qw( git add -A), $build_dir;

    if ( run qw(git status -s -- ), $build_dir ) {
        build_sitemap($build_dir);
        run qw( git add -A), $build_dir;
        say "Commiting changes";
        run qw(git commit -m), 'Updated docs';
    }

    my $remote_sha = eval {
        my $remote = run qw(git rev-parse --symbolic-full-name @{u});
        chomp $remote;
        return sha_for($remote);
    } || '';

    if ( sha_for('HEAD') ne $remote_sha ) {
        if ( $target_repo_checkout ) {
            say "Pushing changes to bare repo";
            run qw(git push origin HEAD );
        }
        local $ENV{GIT_DIR} = $target_repo->git_dir if $target_repo;
        if ( $Opts->{staging} ) {
            say "Force pushing changes to staging";
            run qw(git push -f origin HEAD );
        }
        else {
            say "Pushing changes";
            run qw(git push origin HEAD );
        }
    }
    else {
        say "No changes to push";
    }
}

#===================================
sub init_env {
#===================================
    $ENV{SGML_CATALOG_FILES} = $ENV{XML_CATALOG_FILES} = join ' ',
        file('resources/docbook-xsl-1.78.1/catalog.xml')->absolute,
        file('resources/docbook-xml-4.5/catalog.xml')->absolute;

    print "Old PATH=$ENV{PATH}\n";
    $ENV{PATH}
        = dir('resources/asciidoc-8.6.8/')->absolute
        . ':' . dir('resources/asciidoctor/bin')->absolute
        . ":$FindBin::RealBin:"
        . $ENV{PATH};
    print "New PATH=$ENV{PATH}\n";

    eval { run( 'xsltproc', '--version' ) }
        or die "Please install <xsltproc>";
}

#===================================
sub check_github_authed {
#===================================
    my $fill = _github_creds_fill();

    {
        local $ENV{GIT_TERMINAL_PROMPT} = 0;
        my $creds = git_creds( 'fill', $fill );
        return if $creds =~ /password=\S+/;

    }

    my $creds = git_creds( 'fill', $fill );

# restart after filling in the creds so that ^C or dieing later doesn't reset creds
    if ( $creds =~ /password=\S+/ ) {
        git_creds( 'approve', $creds );
        restart();
    }
    die "GitHub username and password (or auth token) required to continue\n";
}

#===================================
sub revoke_github_creds {
#===================================
    my $fill = _github_creds_fill();
    {
        local $ENV{GIT_TERMINAL_PROMPT} = 0;
        my $creds = git_creds( 'fill', $fill );
        return unless $creds =~ /password=\S+/;
    }

    my $creds = git_creds( 'reject', $fill );
}

#===================================
sub _github_creds_fill {
#===================================
    return $Opts->{user}
        ? "url=https://" . $Opts->{user} . '@github.com'
        : 'url=https://github.com';
}

#===================================
sub ensure_creds_cache_enabled {
#===================================
    local $ENV{GIT_TERMINAL_PROMPT} = 0;

    # test if credential store enabled
    git_creds( 'approve', "url=https://foo.com\nusername=foo\npassword=bar" );
    my $creds = git_creds( 'fill', 'url=https://foo.com' );

    if ( $creds =~ /password=bar/ ) {
        git_creds( 'reject', 'url=https://foo.com' );
        return 1;
    }
    return 0;
}

#===================================
sub enable_creds_cache {
#===================================
    say <<"INFO";

** GitHub doesn't have a credentials store enabled **

I can enable the credentials-cache for you, which will cache
your username and password for 24 hours.
INFO

    $|++;

    print "Enter 'y' if you would like to proceed: ";
    my $yes = <>;
    if ( $yes && $yes =~ /\s*y/i ) {
        say "Enabling credentials cache";
        run( qw(git config --global --add credential.helper),
            "cache --timeout 86400" );
        return 1;
    }
    else {
        say "Credentials cache not enabled";
        return 0;
    }

}

#===================================
sub checkout_staging_or_master {
#===================================
    my $current = eval { run qw(git symbolic-ref --short HEAD) } || 'DETACHED';
    chomp $current;

    my $build_dir = $Conf->{paths}{build}
        or die "Missing <paths.build> in config";

    $build_dir = dir($build_dir);
    $build_dir->mkpath;

    if ( $Opts->{staging} ) {
        return say "*** USING staging BRANCH ***"
            if $current eq 'staging';

        say "*** SWITCHING FROM $current TO staging BRANCH ***";
        run qw(git checkout -B staging);
        restart();
    }
    elsif ( $current eq 'staging' ) {
        say "*** SWITCHING FROM staging TO master BRANCH ***";
        run qw(git checkout master);
        restart();
    }
    elsif ( $current ne 'master' ) {
        say "*** USING $current BRANCH ***";
    }
}

#===================================
sub update_self {
#===================================
    say "Updating docs checkout";
    my $current = eval { run qw(git symbolic-ref --short HEAD) } || 'DETACHED';
    chomp $current;
    my $remote
        = eval { run qw(git rev-parse --abbrev-ref --symbolic-full-name @{u}) }
        || die
        "Couldn't update branch <$current> as it is not tracking an upstream branch\n";
    chomp $remote;
    run qw(git fetch);
    run qw(git clean -df);
    run qw(git reset --hard ), $remote;
    push @Old_ARGV, "--noupdate";
    restart();
}

#===================================
sub restart {
#===================================
    # reexecute script in case it has changed
    my $bin = file($0)->absolute($Old_Pwd);
    say "Restarting";
    chdir $Old_Pwd;
    exec( $^X, $bin, @Old_ARGV );
}

#===================================
sub usage {
#===================================
    say <<USAGE;

    Build local docs:

        $0 --doc path/to/index.asciidoc [opts]

        Opts:
          --single          Generate a single HTML page, instead of
                            a chunking into a file per chapter
          --pdf             Generate a PDF file instead of HTML
          --toc             Include a TOC at the beginning of the page.
          --out dest/dir/   Defaults to ./html_docs.
          --chunk 1         Also chunk sections into separate files
          --open            Open the docs in a browser once built.
          --lenient         Ignore linking errors
          --lang            Defaults to 'en'
          --resource        Path to image dir - may be repeated
          --skiplinkcheck   Omit the step that checks for broken links
          --linkcheckonly   Skips the documentation builds. Checks links only.
          --asciidoctor     Use asciidoctor instead of asciidoc.

        WARNING: Anything in the `out` dir will be deleted!

    Build docs from all repos in conf.yaml:

        $0 --all [opts]

        Opts:
          --push            Commit the updated docs and push to origin
          --staging         Use the template from the staging website
                            and push to the staging branch
          --user            Specify which GitHub user to use, if not your own
          --target_repo     Repository to which to commit docs
          --reference       Directory of `--mirror` clones to use as a local cache
          --rely_on_ssh_auth
                            Skip the git auth check and translate configured repos into ssh
          --rebuild         Rebuild all branches of every book regardless of what has changed
          --no_fetch        Skip fetching updates from source repos

    General Opts:
          --staging         Use the template from the staging website
          --reload_template Force retrieving the latest web template
          --procs           Number of processes to run in parallel, defaults to 3
          --update          Update the docs checkout (losing any changes!)
          --verbose

USAGE
}
