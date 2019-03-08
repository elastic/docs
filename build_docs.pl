#!/usr/bin/env perl

# Flush on every print even if we're writing to a pipe (like docker).
$| = 1;

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
    write_nginx_redirects
    write_nginx_test_config
);

use Getopt::Long qw(:config no_auto_abbrev no_ignore_case no_getopt_compat);
use YAML qw(LoadFile);
use Path::Class qw(dir file);
use Browser::Open qw(open_browser);
use Sys::Hostname;

use ES::BranchTracker();
use ES::Repo();
use ES::Book();
use ES::Toc();
use ES::LinkCheck();
use ES::Template();

GetOptions(
    $Opts,    #
    'all', 'push', 'target_repo=s', 'reference=s', 'rebuild', 'no_fetch', #
    'single',  'pdf',     'doc=s',           'out=s',  'toc', 'chunk=i', 'suppress_migration_warnings',
    'open',    'skiplinkcheck', 'linkcheckonly', 'staging', 'procs=i',         'user=s', 'lang=s',
    'lenient', 'verbose', 'reload_template', 'resource=s@', 'asciidoctor', 'in_standard_docker',
    'conf=s',
) || exit usage();
check_args();

our $Conf = LoadFile(pick_conf());
# The script supports running outside of docker, in any docker container *and*
# running in a docker container that we maintain. If we run in a docker
# container that we maintain then the script will change how it functions
# to support all of its command line arguments properly. At some point we
# will drop support for running outside of our docker image and this will
# always be true, but we aren't there yet.
our $running_in_standard_docker = $Opts->{in_standard_docker};

init_env();

my $template_urls
    = $Conf->{template}{branch}{ $Opts->{staging} ? 'staging' : 'default' };

$Opts->{template} = ES::Template->new(
    %{ $Conf->{template} },
    %$template_urls,
    lenient  => $Opts->{lenient},
    force    => $Opts->{reload_template},
    abs_urls => ! $running_in_standard_docker && $Opts->{doc},
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

    $Opts->{resource}
        = [ map { dir($_)->absolute($Old_Pwd) } @{ $Opts->{resource} || [] } ];

    _guess_opts_from_file($index);

    if ( $Opts->{asciidoctor} && !$running_in_standard_docker ) {
        die "--asciidoctor is only supported by build_docs and not by build_docs.pl";
    }

    my $latest = !$Opts->{suppress_migration_warnings};
    if ( $Opts->{single} ) {
        $dir->rmtree;
        $dir->mkpath;
        build_single( $index, $dir, %$Opts,
                latest => $latest
        );
    }
    else {
        build_chunked( $index, $dir, %$Opts,
                latest => $latest
        );
    }

    say "Done";

    my $html = $dir->file('index.html');

    if ( $Opts->{open} ) {
        say "Opening: " . $html;
        serve_and_open_browser( $dir, 0 );
    }
    else {
        say "See: $html";
    }
}

#===================================
sub _guess_opts_from_file {
#===================================
    my $index = shift;

    my %edit_urls = ();
    my $doc_toplevel = _find_toplevel($index->parent);
    if ( $doc_toplevel ) {
        $Opts->{root_dir} = $doc_toplevel;
        my $edit_url = _guess_edit_url($doc_toplevel);
        @edit_urls{ $doc_toplevel } = $edit_url if $edit_url;
    } else {
        $Opts->{root_dir} = $index->parent;
    }
    for my $resource ( @{ $Opts->{resource} } ) {
        my $resource_toplevel = _find_toplevel($resource);
        next unless $resource_toplevel;

        my $resource_edit_url = _guess_edit_url($resource_toplevel);
        @edit_urls{ $resource_toplevel } = $resource_edit_url if $resource_edit_url;
    }
    $Opts->{edit_urls} = { %edit_urls };
}

#===================================
sub _find_toplevel {
#===================================
    my $docpath = shift;

    my $original_pwd = Cwd::cwd();
    chdir $docpath;
    my $toplevel = eval { run qw(git rev-parse --show-toplevel) };
    chdir $original_pwd;
    say "Couldn't find repo toplevel for $docpath" unless $toplevel;
    return $toplevel;
}

#===================================
sub _guess_edit_url {
#===================================
    my $toplevel = shift;

    local $ENV{GIT_DIR} = dir($toplevel)->subdir('.git');
    my $remotes = eval { run qw(git remote -v) } || '';
    if ($remotes !~ m|\s+(\S+[/:]elastic/\S+)|) {
        say "Couldn't find edit url because there isn't an Elastic clone";
        say "$remotes";
        return;
    }
    my $remote = $1;
    my $branch = eval {run qw(git rev-parse --abbrev-ref HEAD) } || 'master';
    return ES::Repo::edit_url_for_url_and_branch($remote, $branch);
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
    die "--target_repo is required with --all" unless ( $Opts->{target_repo} );

    my ($repos_dir, $temp_dir, $target_repo, $target_repo_checkout) = init_repos();

    my $build_dir = $Conf->{paths}{build}
        or die "Missing <paths.build> in config";
    $build_dir = dir("$target_repo_checkout/$build_dir");
    $build_dir->mkpath;

    my $contents = $Conf->{contents}
        or die "Missing <contents> configuration section";

    my $toc = ES::Toc->new( $Conf->{contents_title} || 'Guide' );
    my $redirects = dir( $target_repo_checkout )->file( 'redirects.conf' );

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

        say "Writing nginx redirects";
        write_nginx_redirects( $redirects, $build_dir, $temp_dir );
    }
    if ( $Opts->{skiplinkcheck} ) {
        say "Skipped Checking links";
    }
    else {
        say "Checking links";
        check_links($build_dir);
    }
    push_changes($build_dir, $target_repo, $target_repo_checkout) if $Opts->{push};
    serve_and_open_browser( $build_dir, $redirects ) if $Opts->{open};

    $temp_dir->rmtree;
}

#===================================
sub check_links {
#===================================
    my $build_dir    = shift;
    my $link_checker = ES::LinkCheck->new($build_dir);

    $link_checker->check;

    check_kibana_links( $build_dir, $link_checker ) if exists $Conf->{repos}{kibana};
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
    my $legacy_path = 'src/legacy/ui/public/documentation_links/documentation_links';
    my $repo     = ES::Repo->get_repo('kibana');

    my @branches = sort map { $_->basename }
        grep { $_->is_dir } $build_dir->subdir('en/kibana')->children;

    for (@branches) {
        $branch = $_;
        next if $branch eq 'current' || $branch =~ /^\d/ && $branch lt 5;
        say "  Branch $branch";
        my $source = eval {
            $repo->show_file( $branch, $src_path . ".js" )
        } || eval {
            $repo->show_file( $branch, $src_path . ".ts" )
        } || eval {
            $repo->show_file( $branch, $legacy_path . ".js" )
        } ||
            $repo->show_file( $branch, $legacy_path . ".ts" );

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

    my $temp_dir = $running_in_standard_docker ? dir('/tmp/docsbuild') : $repos_dir->subdir('.temp');
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

    # Check out the target repo before the other repos so that
    # we can use the tracker file that it contains.
    my $target_repo = ES::Repo->new(
        name      => 'target_repo',
        dir       => $repos_dir,
        user      => $Opts->{user},
        url       => $Opts->{target_repo},
        reference => $reference_dir,
        # intentionally not passing the tracker because we don't want to use it
    );
    delete $child_dirs{ $target_repo->git_dir->absolute };
    my $target_repo_checkout = "$temp_dir/target_repo";
    $tracker_path = "$target_repo_checkout/$tracker_path";
    eval {
        $target_repo->update_from_remote();
        printf(" - %20s: Checking out\n", 'target_repo');
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

    # check out all remaining repos in parallel
    my $tracker = ES::BranchTracker->new( file($tracker_path), @repo_names );
    my $pm = proc_man( $Opts->{procs} * 3 );
    for my $name (@repo_names) {
        my $url = $conf->{$name};
        # We always use ssh-style urls regardless of conf.yaml so we can use
        # our ssh key for the cloning.
        $url =~ s|https://([^/]+)/|git\@$1:|;
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

    local $ENV{GIT_WORK_TREE} = $target_repo_checkout;
    local $ENV{GIT_DIR} = $ENV{GIT_WORK_TREE} . '/.git';

    say 'Building revision.txt';
    $build_dir->file('revision.txt')
        ->spew( iomode => '>:utf8', ES::Repo->all_repo_branches );

    say 'Preparing commit';
    run qw(git add -A);

    if ( run qw(git status -s --) ) {
        build_sitemap($build_dir);
        run qw(git add -A);
        say "Commiting changes";
        run qw(git commit -m), 'Updated docs';
    }

    my $remote_sha = eval {
        my $remote = run qw(git rev-parse --symbolic-full-name @{u});
        chomp $remote;
        return sha_for($remote);
    } || '';

    if ( sha_for('HEAD') ne $remote_sha ) {
        say "Pushing changes to bare repo";
        run qw(git push origin HEAD );
        local $ENV{GIT_DIR} = $target_repo->git_dir if $target_repo;
        say "Pushing changes";
        run qw(git push origin HEAD );
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
        = dir('resources/asciidoc-8.6.8/')->absolute
        . ":$FindBin::RealBin:"
        . $ENV{PATH};

    if ( $running_in_standard_docker ) {
        if (exists $ENV{SSH_AUTH_SOCK}
                && $ENV{SSH_AUTH_SOCK} eq '/tmp/forwarded_ssh_auth') {
            print "Waiting for ssh auth to be forwarded to " . hostname . "\n";
            while (<>) {
                # Read from stdin waiting for the signal that we're ready. We
                # use stdin here because it prevents us from leaving the docker
                # container running if something goes wrong with the forwarding
                # process. The mechanism of action is that when something goes
                # wrong build_docs will die, closing stdin. That will cause us
                # to drop out of this loop and cause the process to terminate.
                last if ($_ eq "ready\n");
            }
            die '/tmp/forwarded_ssh_auth is missing' unless (-e '/tmp/forwarded_ssh_auth');
            print "Found ssh auth\n";
        }
        # If we're in docker we're relying on closing stdin to cause an orderly
        # shutdown because it is really the only way for us to know for sure
        # that the python build_docs process thats on the host is dead.
        # Since perl's threads are "not recommended" we fork early in the run
        # process and have the parent synchronously wait read from stdin. A few
        # things can happen here and each has a comment below:
        if ( my $child_pid = fork ) {
            $SIG{CHLD} = sub {
                # The child process exits so we should exit with whatever
                # exit code it gave us. This can also come about because the
                # child process is killed.
                use POSIX ":sys_wait_h";
                my $child_status = 'missing';
                while ((my $child = waitpid(-1, WNOHANG)) > 0) {
                    my $status = $? >> 8;
                    if ( $child == $child_pid ) {
                        $child_status = $status;
                    } else {
                        # Some other subprocess died on us. The calling code
                        # will handle it.
                    }
                }
                exit $child_status unless ( $child_status eq 'missing');
            };
            $SIG{INT} = sub {
                # We're interrupted. This'll happen if we somehow end up in
                # the foreground. It isn't likely, but if it does happen we
                # should interrupt the child just in case it wasn't already
                # interrupted and then exit with whatever code the child exits
                # with.
                kill 'INT', $child_pid;
                wait;
                exit $? >> 8;
            };
            $SIG{TERM} = sub {
                # We're terminated. We should pass on the love to the
                # child process and return its exit code.
                kill 'TERM', $child_pid;
                wait;
                exit $? >> 8;
            };
            while (<>) {}
            # STDIN is closed. This'll happen if the python build_docs process
            # on the host dies for some reason. When the host process dies we
            # should do our best to die too so the docker container exits and
            # is removed. We do that by interrupting the child and exiting with
            # whatever exit code it exits with.
            kill 'TERM', $child_pid;
            wait;
            exit $? >> 8;
        }

        # If we're running in docker then we won't have a useful username
        # so we hack one into place with nss wrapper.
        open(my $override, '>', '/tmp/passwd')
            or dir("Couldn't write override user file");
        # We use the `id` command here because it fetches the id. The native
        # perl way to do this (getpwuid($<)) doesn't work because it needs a
        # complete user. And we *aren't* one.
        my $uid = `id -u`;
        my $gid = `id -g`;
        chomp($uid);
        chomp($gid);
        print $override "docker:x:$uid:$gid:docker:/tmp:/bin/bash\n";
        close $override;
        $ENV{LD_PRELOAD} = '/usr/lib/libnss_wrapper.so';
        $ENV{NSS_WRAPPER_PASSWD} = '/tmp/passwd';
        $ENV{NSS_WRAPPER_GROUP} = '/etc/group';
    }

    eval { run( 'xsltproc', '--version' ) }
        or die "Please install <xsltproc>";
}

#===================================
sub check_args {
#===================================
    if ( $Opts->{doc} ) {
        die('--target_repo not compatible with --doc') if $Opts->{target_repo};
        die('--push not compatible with --doc') if $Opts->{push};
        die('--user not compatible with --doc') if $Opts->{user};
        die('--reference not compatible with --doc') if $Opts->{reference};
        die('--rebuild not compatible with --doc') if $Opts->{rebuild};
        die('--no_fetch not compatible with --doc') if $Opts->{no_fetch};
        die('--skiplinkcheck not compatible with --doc') if $Opts->{skiplinkcheck};
        die('--linkcheckonly not compatible with --doc') if $Opts->{linkcheckonly};
    } else {
        die('--single not compatible with --all') if $Opts->{single};
        die('--pdf not compatible with --all') if $Opts->{pdf};
        die('--toc not compatible with --all') if $Opts->{toc};
        die('--out not compatible with --all') if $Opts->{out};
        die('--chunk not compatible with --all') if $Opts->{chunk};
        die('--lenient not compatible with --all') if $Opts->{lenient};
        # Lang will be 'en' even if it isn't specified so we don't check it.
        die('--resource not compatible with --all') if $Opts->{resource};
        die('--asciidoctor not compatible with --all') if $Opts->{asciidoctor};
    }
}

#===================================
sub pick_conf {
#===================================
    return 'conf.yaml' unless $Opts->{conf};

    my $conf = dir($Old_Pwd)->file($Opts->{conf});
    return $conf if -e $conf;
    die $Opts->{conf} . " doesn't exist";
}

#===================================
# Serve the documentation that we just built and open a browser to look at it.
#
# docs_dir        - directory containing generated docs : Path::Class::dir
# redirects_file  - file containing redirects or 0 if there aren't
#                 - any redirects : Path::Class::file||0
#===================================
sub serve_and_open_browser {
#===================================
    my ( $docs_dir, $redirects_file ) = @_;

    if ( my $pid = fork ) {
        # parent
        $SIG{INT} = sub {
            kill -9, $pid;
        };
        if ( not $running_in_standard_docker ) {
            sleep 1;
            say "Press Ctrl-C to exit the web server";
            open_browser("http://localhost:8000/");
        }

        wait;
        say "\nExiting";
        exit;
    }
    else {
        if ( $running_in_standard_docker ) {
            # We use nginx to serve files instead of the python built in web server
            # when we're running inside docker because the python web server performs
            # badly there. nginx is fine.
            my $nginx_config = file('/tmp/nginx.conf');
            write_nginx_test_config( $nginx_config, $docs_dir, $redirects_file );
            close STDIN;
            open( STDIN, "</dev/null" );
            exec( qw(nginx -c), $nginx_config );
        } else {
            my $http = dir( 'resources', 'http.py' )->absolute;
            close STDIN;
            open( STDIN, "</dev/null" );
            chdir $docs_dir;
            exec( $http '8000' );
        }
    }
}

#===================================
sub usage {
#===================================
    my $name = $Opts->{in_standard_docker} ? 'build_docs' : $0;
    say <<USAGE;

    Build local docs:

        $name --doc path/to/index.asciidoc [opts]

        Opts:
          --single          Generate a single HTML page, instead of
                            a chunking into a file per chapter
          --pdf             Generate a PDF file instead of HTML
          --toc             Include a TOC at the beginning of the page.
          --out dest/dir/   Defaults to ./html_docs.
          --chunk 1         Also chunk sections into separate files
          --lenient         Ignore linking errors
          --lang            Defaults to 'en'
          --resource        Path to image dir - may be repeated
          --asciidoctor     Use asciidoctor instead of asciidoc.
          --suppress_migration_warnings
                            Suppress warnings about Asciidoctor migration
                            issues. Use this when building "old" branches.

        WARNING: Anything in the `out` dir will be deleted!

    Build docs from all repos in conf.yaml:

        $name --all --target_repo <target> [opts]

        Opts:
          --target_repo     Repository to which to commit docs
          --push            Commit the updated docs and push to origin
          --user            Specify which GitHub user to use, if not your own
          --reference       Directory of `--mirror` clones to use as a local cache
          --skiplinkcheck   Omit the step that checks for broken links
          --linkcheckonly   Skips the documentation builds. Checks links only.
          --rebuild         Rebuild all branches of every book regardless of what has changed
          --no_fetch        Skip fetching updates from source repos

    General Opts:
          --staging         Use the template from the staging website
          --reload_template Force retrieving the latest web template
          --procs           Number of processes to run in parallel, defaults to 3
          --verbose
          --in_standard_docker
                            Specified by build_docs when running in its container
          --conf <ymlfile>  Use your own configuration file, defaults to the bundled conf.yaml
          --open            Open the docs in a browser once built.

USAGE
    if ( $Opts->{in_standard_docker} ) {
        say <<USAGE;
    Self Test:

        $name --self-test <args to pass to make>

    `--self-test` is a wrapper around `make` which is used exclusively for
    testing. Like `make`, the current directory selects the `Makefile` and
    you can make specific targets. Some examples:

    Execute all tests:
        $name --self-test

    Execute all of the tests for our extensions to Asciidoctor:
        $name --self-test -C resources/asciidoctor

    Run rubocop on our extensions to Asciidoctor:
        $name --self-test -C resources/asciidoctor rubocop
    
USAGE
    }
}
