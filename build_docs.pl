#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;

our ($Old_Pwd);
our @Old_ARGV = @ARGV;

use Cwd;
use FindBin;
use Data::Dumper;
use URI();

BEGIN {
    $Old_Pwd = Cwd::cwd();
    chdir "$FindBin::RealBin/";
}

use lib 'lib';
use Proc::PID::File;
die "$0 already running\n" if Proc::PID::File->running( dir => '.run' );

use ES::Util qw(
    run $Opts
    build_chunked build_single
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
    'all', 'push',    #
    'single',  'doc=s',   'out=s',   'toc', 'chunk=i', 'comments',
    'open',    'staging', 'procs=i', 'user=s',
    'lenient', 'verbose', 'reload_template'
) || exit usage();

our $Conf = LoadFile('conf.yaml');

checkout_staging_or_master();
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

    say "Building HTML from $doc";

    my $dir = dir( $Opts->{out} || 'html_docs' )->absolute($Old_Pwd);
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
            my $http = dir( 'resources', 'http.py' )->absolute;
            close STDIN;
            open( STDIN, "</dev/null" );
            chdir $dir;
            exec( $http '8000' );
        }
    }
    else {
        say "See: $html";
    }
}

#===================================
sub build_all {
#===================================
    say "Checking GitHub username and password";

    ensure_creds_cache_enabled() || enable_creds_cache() || exit;
    check_github_authed();

    init_repos();

    my $build_dir = $Conf->{paths}{build}
        or die "Missing <paths.build> in config";

    $build_dir = dir($build_dir);
    $build_dir->mkpath;

    my $contents = $Conf->{contents}
        or die "Missing <contents> configuration section";

    my $toc = ES::Toc->new( $Conf->{contents_title} || 'Guide' );
    build_entries( $build_dir, $toc, @$contents );

    say "Writing main TOC";
    $toc->write( $build_dir, 0 );

    say "Writing extra HTML redirects";
    for ( @{ $Conf->{redirects} } ) {
        write_html_redirect( $build_dir->subdir( $_->{prefix} ),
            $_->{redirect} );
    }

    check_links($build_dir);

    push_changes($build_dir)
        if $Opts->{push};
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

    my $re = qr|`\$\{baseUrl\}guide/(.+)\$\{urlVersion\}([^#`]+)(?:#([^`*]))?`|;

    my $extractor = sub {
        my $contents = shift;
        return sub {
            while ( $contents =~ m{$re}g ) {
                return ( $1 . $branch . $2, $3 );
            }
            return;
        };

    };

    my $src_path = 'src/ui/public/documentation_links/documentation_links.js';
    my $repo     = ES::Repo->get_repo('kibana');

    my @branches = sort map { $_->basename }
        grep { $_->is_dir } $build_dir->subdir('en/kibana')->children;

    for (@branches) {
        $branch = $_;
        next if $branch eq 'current' || $branch =~ /^\d/ && $branch lt 5;
        say "  Branch $branch";
        $repo->checkout($branch);
        $link_checker->check_file( $repo->dir->file($src_path),
            $extractor, "Kibana [$branch]: $src_path" );
    }
}

#===================================
sub build_entries {
#===================================
    my ( $build, $toc, @entries ) = @_;

    while ( my $entry = shift @entries ) {
        my $title = $entry->{title}
            or die "Missing title for entry: " . Dumper($entry);

        if ( my $sections = $entry->{sections} ) {
            my $base_dir = $entry->{base_dir} || '';
            my $section_toc = build_entries( $build->subdir($base_dir),
                ES::Toc->new($title), @$sections );
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
            %$entry
        );
        $toc->add_entry( $book->build );
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

    my $temp_dir = $repos_dir->subdir('.temp');
    $temp_dir->rmtree;

    my $conf = $Conf->{repos}
        or die "Missing <repos> in config";

    my @repo_names = sort keys %$conf;

    my $tracker_path = $Conf->{paths}{branch_tracker}
        or die "Missing <paths.branch_tracker> in config";

    my $tracker = ES::BranchTracker->new( file($tracker_path), @repo_names );
    my $pm = proc_man( $Opts->{procs} * 3 );
    for my $name (@repo_names) {
        my $url = $conf->{$name}{url};
        if ( $Opts->{user} ) {
            $url = URI->new($url);
            $url->userinfo( $Opts->{user} );
        }
        my $repo = ES::Repo->new(
            name     => $name,
            dir      => $repos_dir,
            temp_dir => $temp_dir,
            tracker  => $tracker,
            %{ $conf->{$name} },
            url => $url
        );
        $pm->start($name) and next;
        eval {
            $repo->update_from_remote();
            1;
        } or do {
            my $error = $@;
            if ( $error =~ /Invalid username or password/ ) {
                revoke_github_creds();
            }
            die $error;
        };
        $pm->finish;
    }
    $pm->wait_all_children;

    for my $dir ( $repos_dir->children ) {
        next unless $dir->is_dir;
        my $basename = $dir->basename;
        next if $conf->{$basename};
        say "Removing old repo <$basename>";
        $dir->rmtree;
    }
    $temp_dir->mkpath;
}

#===================================
sub push_changes {
#===================================
    my $build_dir = shift;

    $build_dir->file('revision.txt')
        ->spew( iomode => '>:utf8', ES::Repo->all_repo_branches );

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

    $ENV{PATH}
        = dir('resources/asciidoc-8.6.8/')->absolute . ':' . $ENV{PATH};

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

    if ( $creds =~ /password=\S+/ ) {
        git_creds( 'approve', $creds );
        restart();
    }
    die "Username and password for GitHub required to continue\n";
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
          --toc             Include a TOC at the beginning of the page.
          --out dest/dir/   Defaults to ./html_docs.
          --chunk 1         Also chunk sections into separate files
          --comments        Make // comments visible

          --open            Open the docs in a browser once built.
          --lenient         Ignore linking errors
          --staging         Use the template from the staging website
          --reload_template Force retrieving the latest web template
          --procs           Number of processes to run in parallel, defaults to 3
          --user            Specify which GitHub user to use, if not your own
          --verbose

        WARNING: Anything in the `out` dir will be deleted!

    Build docs from all repos in conf.yaml:

        $0 --all [opts]

        Opts:
          --push            Commit the updated docs and push to origin
          --staging         Use the template from the staging website
                            and push to the staging branch
          --verbose

USAGE
}
