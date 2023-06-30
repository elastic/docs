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
use XML::LibXML;

BEGIN {
    $Old_Pwd = Cwd::cwd();
    chdir "$FindBin::RealBin/";
}

use lib 'lib';

use ES::Util qw(
    run $Opts
    build_chunked build_single
    proc_man
    timestamp
    write_html_redirect
    write_nginx_redirects
    write_nginx_test_config
    write_nginx_preview_config
    start_web_resources_watcher
    start_preview
    build_web_resources
);

use Getopt::Long qw(:config no_auto_abbrev no_ignore_case no_getopt_compat);
use YAML qw(LoadFile);
use Path::Class qw(dir file);
use Sys::Hostname;

use ES::BranchTracker();
use ES::DocsRepo();
use ES::Repo();
use ES::Book();
use ES::TargetRepo();
use ES::Toc();
use ES::LinkCheck();

GetOptions($Opts, @{ command_line_opts() }) || exit usage();
check_opts();

our $ConfPath = pick_conf();
our $Conf = LoadFile($ConfPath);
# We no longer support running outside of our "standard" docker container.
# `build_docs` signals to us that it is in the standard docker container by
# passing this argument.
die 'build_docs.pl is unsupported. Use build_docs instead' unless $Opts->{in_standard_docker};

if ( $Opts->{asciidoctor} ) {
    say <<MSG
The Asciidoctor migration is complete! --asciidoctor will emit this message
forever in honor of our success but otherwise doesn't do anything.
MSG
}
if ( $Opts->{direct_html} ) {
   say <<MSG
The direct_html migration is complete! --direct_html will emit this message
forever in honor of our success but otherwise doesn't do anything.
MSG
}

init_env();

$Opts->{doc}           ? build_local()
    : $Opts->{all}     ? build_all()
    : $Opts->{preview} ? preview()
    :                    usage();

#===================================
sub build_local {
#===================================
    my $doc = $Opts->{doc};


    my $index = file($doc)->absolute($Old_Pwd);
    die "File <$doc> doesn't exist" unless -f $index;

    say "Building HTML from $doc";

    my $dir = dir( $Opts->{out} || 'html_docs' )->absolute($Old_Pwd);
    my $raw_dir = $dir->subdir( 'raw' );

    $Opts->{resource}
        = [ map { dir($_)->absolute($Old_Pwd) } @{ $Opts->{resource} || [] } ];

    _guess_opts( $index );
    $Opts->{roots}{docs} = '/docs_build' unless $Opts->{roots}{docs};

    my @alternatives;
    if ( $Opts->{alternatives} ) {
        for ( @{ $Opts->{alternatives} } ) {
            my @parts = split /:/;
            unless (scalar @parts == 3) {
                die "alternatives must contain exactly two :s but was [$_]";
            }
            push @alternatives, {
                source_lang => $parts[0],
                alternative_lang => $parts[1],
                dir => $parts[2],
            };
        }
    }

    # Get a head start on web resources if we're going to need them.
    my $web_resources_pid = start_web_resources_watcher if $Opts->{open};

    my $latest = !$Opts->{suppress_migration_warnings};
    if ( $Opts->{single} ) {
        build_single( $index, $raw_dir, $dir, %$Opts,
                latest       => $latest,
                alternatives => \@alternatives,
                relativize => 0,
        );
    }
    else {
        build_chunked( $index, $raw_dir, $dir, %$Opts,
                latest       => $latest,
                alternatives => \@alternatives,
                relativize => 0,
        );
    }

    say "Done";

    if ( $Opts->{open} ) {
        my $preview_pid = start_preview( 'fs', $raw_dir, 'template.html', 0 );
        serve_local_preview( $dir, 0, $web_resources_pid, $preview_pid );
    }
}

#===================================
sub _guess_opts {
#===================================
    my $index = shift;

    $Opts->{edit_urls} = {};
    $Opts->{roots} = {};
    my $toplevel = _find_toplevel( $index->parent );
    my $remote = _pick_best_remote( $toplevel );
    my $branch = _guess_branch( $toplevel );
    my $repo_name = _guess_repo_name( $remote );
    # We couldn't find the top level so lets make a wild guess.
    $toplevel = $index->parent unless $toplevel;
    printf "Guessed toplevel=[%s] remote=[%s] branch=[%s] repo=[%s]\n", $toplevel, $remote, $branch, $repo_name;

    $Opts->{branch} = $branch;
    $Opts->{roots}{ $repo_name } = $toplevel;
    $Opts->{edit_urls}{ $toplevel } = ES::Repo::edit_url_for_url_and_branch(
        $remote || 'unknown', $branch
    );
    for my $resource ( @{ $Opts->{resource} } ) {
        $toplevel = _find_toplevel( $resource );
        $remote = _pick_best_remote( $toplevel );
        $branch = _guess_branch( $toplevel );
        $repo_name = _guess_repo_name( $remote );
        # We couldn't find the top level so lets make a wild guess.
        $toplevel = $resource unless $toplevel;
        $Opts->{roots}{ $repo_name } = $toplevel;
        $Opts->{edit_urls}{ $toplevel } = ES::Repo::edit_url_for_url_and_branch(
            $remote || 'unknown', $branch
        );
    }
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
    return $toplevel || 0;
}

#===================================
sub _pick_best_remote {
#===================================
    my $toplevel = shift;

    return 0 unless $toplevel;

    local $ENV{GIT_DIR} = dir($toplevel)->subdir('.git');
    my $projectName = dir( $toplevel )->basename;

    my $remotes = eval { run qw(git remote -v) } || '';

    # We prefer either an elastic or elasticsearch-cn organization. All
    # but two books are in elastic but elasticsearch-cn is special.
    if ($remotes =~ m|\s+(\S+[/:]elastic(?:search-cn)?/$projectName)\.git|) {
        # Prefer a remote with the same name as the working directory, if it exists
        return $1;
    }
    if ($remotes =~ m|\s+(\S+[/:]elastic(?:search-cn)?/\S+)|) {
        # Otherwise, take any remote from one of the preferred organizations
        return $1;
    }
    say "Couldn't find an Elastic remote for $toplevel. Generating edit links targeting the first remote instead.";
    if ($remotes =~ m|\s+(\S+[/:]\S+/\S+)|) {
        return $1;
    }
    return 0;
}

#===================================
sub _guess_branch {
#===================================
    my $toplevel = shift;

    return 'master' unless $toplevel;

    local $ENV{GIT_DIR} = dir($toplevel)->subdir('.git');
    my $real_branch = eval { run qw(git rev-parse --abbrev-ref HEAD) } || 'master';

    # Detects common branch patterns like:
    # 7.x
    # 7.1
    # 18.5
    # Also normalizes brackport style patters like:
    # blah_blah_7.x
    # bort_foo_7_x
    # zip_zop_12.8
    # qux_12_8
    return $1 if $real_branch =~ /(\d+[\._][\dx]+)$/;

    # Otherwise we just assume we're trageting master. This'll be right when
    # the branch is actually 'master' and when this is a feature branch. It
    # obviously won't always be right, but for the most part that *should* be
    # ok because we have pull request builds which will double check the links.
    return 'master';
}

#===================================
sub _guess_repo_name {
#===================================
    my ( $remote ) = @_;

    return 'repo' unless $remote;

    $remote = dir( $remote )->basename;
    $remote =~ s/\.git$//;

    return $remote;
}

#===================================
sub build_all {
#===================================
    $Opts->{target_repo} = 'git@github.com:elastic/built-docs.git' unless ( $Opts->{target_repo} );

    my ( $repos_dir, $temp_dir, $reference_dir ) = init_dirs();

    say "Updating repositories";
    my $target_repo = init_target_repo( $repos_dir, $temp_dir, $reference_dir );
    my $tracker = init_repos(
            $repos_dir, $temp_dir, $reference_dir, $target_repo );

    my $build_dir = $target_repo->destination->subdir( 'html' );
    $build_dir->mkpath;
    my $raw_build_dir = $target_repo->destination->subdir( 'raw' );

    my $contents = $Conf->{contents}
        or die "Missing <contents> configuration section";

    my $toc_extra = $Conf->{toc_extra} ? $ConfPath->parent->file( $Conf->{toc_extra} ) : 0;
    my $toc = ES::Toc->new( $Conf->{contents_title} || 'Guide', $toc_extra );
    my $redirects = $target_repo->destination->file( 'redirects.conf' );

    if ( $Opts->{linkcheckonly} ){
        say "Skipping documentation builds."
    }
    else {
        say "Building docs";
        build_entries(
            $raw_build_dir, $build_dir, $temp_dir, $toc, $tracker, @$contents
        );

        say "Writing main TOC";
        $toc->write( $raw_build_dir, $build_dir, $temp_dir, 0 );

        build_web_resources( $target_repo->destination );

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
    $tracker->prune_out_of_date;
    push_changes( $build_dir, $target_repo, $tracker ) if $Opts->{push};
    serve_local_preview( $build_dir, $redirects, 0, 0 ) if $Opts->{open};

    $temp_dir->rmtree;
}

#===================================
sub check_links {
#===================================
    my $build_dir    = shift;
    my $link_checker = ES::LinkCheck->new($build_dir);

    $link_checker->check;

    check_kibana_links( $build_dir, $link_checker ) if exists $Conf->{repos}{kibana};
    # Comment out due to build errors
    # check_elasticsearch_links( $build_dir, $link_checker ) if exists $Conf->{repos}{elasticsearch};
    if ( $link_checker->has_bad || $Opts->{warnlinkcheck}) {
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
    my $version;

    say "Checking Kibana links";

    my $extractor = sub {
        my $contents = shift;
        return sub {
            while ( $contents =~ m!`(\$\{(?:baseUrl|ELASTIC_WEBSITE_URL|ELASTIC_DOCS|KIBANA_DOCS|PLUGIN_DOCS|FLEET_DOCS|APM_DOCS|STACK_DOCS|SECURITY_SOLUTION_DOCS|STACK_GETTING_STARTED|APP_SEARCH_DOCS|ENTERPRISE_SEARCH_DOCS|WORKPLACE_SEARCH_DOCS)\}[^`]+)`!g ) {
                my $path = $1;
                $path =~ s/\$\{(?:DOC_LINK_VERSION|urlVersion)\}/$version/;
                # In older versions, the variable `${ELASTIC_DOCS}` referred to
                # the Elasticsearch Guide. In newer branches, the
                # variable is called `${ELASTICSEARCH_DOCS}`
                $path =~ s!\$\{ELASTIC_DOCS\}!en/elasticsearch/reference/$version/!;
                $path =~ s!\$\{ELASTICSEARCH_DOCS\}!en/elasticsearch/reference/$version/!;
                $path =~ s!\$\{KIBANA_DOCS\}!en/kibana/$version/!;
                $path =~ s!\$\{PLUGIN_DOCS\}!en/elasticsearch/plugins/$version/!;
                $path =~ s!\$\{FLEET_DOCS\}!en/fleet/$version/!;
                $path =~ s!\$\{APM_DOCS\}!en/apm/!;
                $path =~ s!\$\{STACK_DOCS\}!en/elastic-stack/$version/!;
                $path =~ s!\$\{SECURITY_SOLUTION_DOCS\}!en/security/$version/!;
                $path =~ s!\$\{STACK_GETTING_STARTED\}!en/elastic-stack-get-started/$version/!;
                $path =~ s!\$\{APP_SEARCH_DOCS\}!en/app-search/$version/!;
                $path =~ s!\$\{ENTERPRISE_SEARCH_DOCS\}!en/enterprise-search/$version/!;
                $path =~ s!\$\{WORKPLACE_SEARCH_DOCS\}!en/workplace-search/$version/!;
                $path =~ s!\$\{MACHINE_LEARNING_DOCS\}!en/machine-learning/$version/!;
                # Replace the "https://www.elastic.co/guide/" URL prefix so that
                # it becomes a file path in the built docs.
                $path =~ s!\$\{(?:baseUrl|ELASTIC_WEBSITE_URL)\}guide/!!;
                # We don't want to check any links to www.elastic.co that aren't
                # part of the docs.
                return "" if $path =~ m/\$\{(?:baseUrl|ELASTIC_WEBSITE_URL)\}.*/;
                # Otherwise, return the link to check
                return ( split /#/, $path );
            }
            return;
        };

    };

    my $src_path = 'src/ui/public/documentation_links/documentation_links';
    my $legacy_path = 'src/legacy/ui/public/documentation_links/documentation_links';
    my $repo     = ES::Repo->get_repo('kibana');

    my @versions = sort map { $_->basename }
        grep { $_->is_dir } $build_dir->subdir('en/kibana')->children;

    my $link_check_name = 'link-check-kibana';

    for (@versions) {
        $version = $_;
        next if $version eq 'current' || $version =~ /^\d/ && $version lt 5;
        # @versions is looping through the directories in the output (which
        # still contains `master`), but we need to look in the `main` branch of
        # the Kibana repo for this file.
        #
        # TODO: remove as part of
        # https://github.com/elastic/docs/issues/2264
        $branch = $version eq "master" ? "main" : $version;
        say "  Branch: $branch, Version: $version";
        my $links_file;
        my $source = eval {
            $links_file = "packages/kbn-doc-links/src/get_doc_links.ts";
            $repo->show_file( $link_check_name, $branch, $links_file );
        } || eval {
            $links_file = $src_path . ".js";
            $repo->show_file( $link_check_name, $branch, $links_file );
        } || eval {
            $links_file = $src_path . ".ts";
            $repo->show_file( $link_check_name, $branch, $links_file );
        } || eval {
            $links_file = $legacy_path . ".js";
            $repo->show_file( $link_check_name, $branch, $links_file );
        } || eval {
            $links_file = $legacy_path . ".ts";
            $repo->show_file( $link_check_name, $branch, $links_file );
        } || eval {
            $links_file = "src/core/public/doc_links/doc_links_service.ts";
            $repo->show_file( $link_check_name, $branch, $links_file );
        };
        die "failed to find kibana links file;\n$@" unless $source;

        $link_checker->check_source( $source, $extractor,
            "Kibana [$version]: $links_file" );

        # Mark the file that we need for the link check done so we can use
        # --keep_hash with it during some other build.
        $repo->mark_done( $link_check_name, $branch, $links_file, 0 );
    }
}

#===================================
sub check_elasticsearch_links {
#===================================
    my $build_dir    = shift;
    my $link_checker = shift;
    my $branch;
    my $version;

    say "Checking Elasticsearch links";

    # Grab URLs from the JSON file. This is lame, but we sort of need to parse
    # using regexes because that's what the rest of the infrastructure expects.
    # So we grab all quoted strings that contain `html`. This *should* be fine
    # for a while because the keys in the file are all in SHOUTING_SNAKE_CASE
    # so even if one contains "html" it'll contain "HTML" which doesn't match.
    my $extractor = sub {
        my $contents = shift;
        return sub {
            while ( $contents =~ m!"([^"\#]+)(?:\#([^"]+))?"!g ) {
                my $path = $1;
                next unless $path =~ m!html!;
                return "en/elasticsearch/reference/$version/$path";
            }
            return;
        };
    };

    my $src_path = 'server/src/main/resources/org/elasticsearch/common/reference-docs-links.json';
    my $repo     = ES::Repo->get_repo('elasticsearch');

    my @versions = sort map { $_->basename }
        grep { $_->is_dir } $build_dir->subdir('en/elasticsearch/reference')->children;

    my $link_check_name = 'link-check-elasticsearch';

    for (@versions) {
        $version = $_;
        # check versions after 8.6
        next if $version eq 'current' || $version =~ /^(\d+)\.(\d+)/ && ($1 lt 8 || ($1 eq 8 && $2 lt 7));
        # @versions is looping through the directories in the output (which
        # still contains `master`), but we need to look in the `main` branch of
        # the ES repo for this file.
        #
        # TODO: remove as part of
        # https://github.com/elastic/docs/issues/2264
        $branch = $version eq "master" ? "main" : $version;
        say "  Branch: $branch, Version: $version";
        my $source = $repo->show_file( $link_check_name, $branch, $src_path );

        $link_checker->check_source( $source, $extractor,
            "Elasticsearch [$version]: $src_path" );

        # Mark the file that we need for the link check done so we can use
        # --keep_hash with it during some other build.
        $repo->mark_done( $link_check_name, $branch, $src_path, 0 );
    }
}


#===================================
sub build_entries {
#===================================
    my ( $raw_build, $build, $temp_dir, $toc, $tracker, @entries ) = @_;

    while ( my $entry = shift @entries ) {
        my $title = $entry->{title}
            or die "Missing title for entry: " . Dumper($entry);

        if ( my $sections = $entry->{sections} ) {
            my $base_dir = $entry->{base_dir} || '';
            my $raw_sub_build = $raw_build->subdir($base_dir);
            my $sub_build = $build->subdir($base_dir);
            my $toc_extra = $entry->{toc_extra} ? $ConfPath->parent->file( $entry->{toc_extra} ) : 0;
            my $section_toc = build_entries(
                $raw_sub_build, $sub_build, $temp_dir,
                ES::Toc->new( $title, $toc_extra, $entry->{lang} ),
                $tracker, @$sections
            );
            if ($base_dir) {
                $section_toc->write( $raw_sub_build, $sub_build, $temp_dir );
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
            raw_dir  => $raw_build,
            temp_dir => $temp_dir,
            %$entry
        );
        $toc->add_entry( $book->build( $Opts->{rebuild}, $ConfPath ) );
        $tracker->allowed_book( $book );
    }

    return $toc;
}

#===================================
sub build_sitemap {
#===================================
    my ( $dir, $changed ) = @_;

    # Build the sitemap by iterating over all of the toc and index files. Uses
    # the old sitemap to populate the dates for files that haven't changed.
    # Use "now" for files that have.

    my $sitemap = $dir->file('sitemap.xml');
    my $now = timestamp();
    my %dates;

    if ( -e $sitemap ) {
        my $doc = XML::LibXML->load_xml( location => $sitemap );
        for ($doc->firstChild->childNodes) {
            next unless $_->nodeName eq 'url';
            my $loc;
            my $lastmod;
            for ($_->childNodes) {
                $loc = $_->to_literal if $_->nodeName eq 'loc';
                $lastmod = $_->to_literal if $_->nodeName eq 'lastmod';
            }
            die "Dind't find <loc> in $_" unless $loc;
            die "Dind't find <lastmod> in $_" unless $lastmod;
            $loc =~ s|https://www.elastic.co/guide/||;
            $dates{$loc} = $lastmod;
        }
    }
    for ( split /\0/, $changed ) {
        next unless s|^html/||;
        $dates{$_} = $now;
    }

    # Build a list of the files we're going to index and sort it so entries in
    # the sitemap don't "jump around".
    my @files;
    $dir->recurse(
        callback => sub {
            my $item = shift;

            return unless $item->is_dir && $item->basename eq 'current';
            if ( -e $item->file('toc.html') ) {
                my $content = $item->file('toc.html')
                    ->slurp( iomode => '<:encoding(UTF-8)' );
                push @files, $item->file($_)
                    for ( $content =~ /href="([^"]+)"/g );
            }
            elsif ( -e $item->file('index.html') ) {
                push @files, $item->file('index.html');
            }
            return $item->PRUNE;
        }
    );
    @files = sort @files;

    open my $fh, '>', $sitemap or die "Couldn't create $sitemap: $!";
    say $fh <<SITEMAP_START;
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
SITEMAP_START

    for ( @files ) {
        my $loc  = $_->relative($dir);
        my $url  = "https://www.elastic.co/guide/$loc";
        my $date = $dates{$loc};
        die "Couldn't find a modified time for $loc" unless $date;
        say $fh <<ENTRY;
<url>
    <loc>$url</loc>
    <lastmod>$date</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.5</priority>
</url>
ENTRY
    }

    say $fh "</urlset>";
    close $fh or die "Couldn't close $sitemap: $!"
}

#===================================
sub init_dirs {
#===================================
    my $repos_dir = $Opts->{reposcache} || '.repos';
    $repos_dir = dir($repos_dir)->absolute;
    $repos_dir->mkpath;

    my $temp_dir = dir('/tmp/docsbuild');
    $temp_dir = $temp_dir->absolute;
    $temp_dir->rmtree;
    $temp_dir->mkpath;

    my $reference_dir = dir($Opts->{reference});
    if ( $reference_dir ) {
        $reference_dir = $reference_dir->absolute;
        die "Missing reference directory $reference_dir" unless -e $reference_dir;
    }

    return ( $repos_dir, $temp_dir, $reference_dir );
}

#===================================
sub init_target_repo {
#===================================
    my ( $repos_dir, $temp_dir, $reference_dir ) = @_;

    my $target_repo = ES::TargetRepo->new(
        git_dir     => $repos_dir->subdir('target_repo.git'),
        url         => $Opts->{target_repo},
        reference   => $reference_dir,
        destination => dir( "$temp_dir/target_repo" ),
        branch      => $Opts->{target_branch} || 'master',
    );
    $target_repo->update_from_remote;
    return $target_repo;
}

#===================================
sub init_repos {
#===================================
    my ( $repos_dir, $temp_dir, $reference_dir, $target_repo ) = @_;

    printf(" - %20s: Checking out minimal\n", 'target_repo');
    $target_repo->checkout_minimal();

    my %child_dirs = map { $_ => 1 } $repos_dir->children;
    delete $child_dirs{ $temp_dir->absolute };

    my $conf = $Conf->{repos}
        or die "Missing <repos> in config";

    my @repo_names = sort keys %$conf;

    delete $child_dirs{ $target_repo->git_dir->absolute };

    my $tracker_path = $target_repo->destination . '/html/branches.yaml';

    # check out all remaining repos in parallel
    my $tracker = ES::BranchTracker->new( file($tracker_path), @repo_names );
    my $pm = proc_man( $Opts->{procs} * 3 );
    unless ( $pm->start('target_repo') ) {
        printf(" - %20s: Checking out remaining\n", 'target_repo');
        $target_repo->checkout_all();
        $pm->finish;
    }
    for my $name (@repo_names) {
        next if $name eq 'docs';

        my $url = $conf->{$name};
        # We always use ssh-style urls regardless of conf.yaml so we can use
        # our ssh key for the cloning.
        $url =~ s|https://([^/]+)/|git\@$1:|;
        my $repo = ES::Repo->new(
            name      => $name,
            git_dir   => $repos_dir->subdir("$name.git"),
            tracker   => $tracker,
            url       => $url,
            reference => $reference_dir,
            keep_hash => $Opts->{keep_hash} || 0,
        );
        delete $child_dirs{ $repo->git_dir->absolute };

        if ( $Opts->{linkcheckonly} ){
            say "Skipping fetching repo $name."
        }
        else {
            $pm->start($name) and next;
            $repo->update_from_remote();
            $pm->finish;
        }
    }
    $pm->wait_all_children;

    # Parse the --sub_dir options and attach the to the repo
    my %sub_dirs = ();
    foreach (@{ $Opts->{sub_dir} }) {
        die "invalid --sub_dir $_"
            unless /(?<repo>[^:]+):(?<branch>[^:]+):(?<dir>.+)/;
        my $dir = dir($+{dir})->absolute;
        die "--sub_dir $dir doesn't exist" unless -e $dir;
        ES::Repo->get_repo($+{repo})->add_sub_dir($+{branch}, $dir);
    }

    for ( keys %child_dirs ) {
        my $dir = dir($_);
        next unless -d $dir;
        say "Removing old repo <" . $dir->basename . ">";
        $dir->rmtree;
    }

    # Setup the docs repo
    # We support configuring the remote for the docs repo for testing
    ES::DocsRepo->new(
        tracker => $tracker,
        dir => $conf->{docs} || '/docs_build',
        keep_hash => $Opts->{keep_hash} || 0
    );

    return $tracker;
}


#===================================
sub preview {
#===================================
    $Opts->{target_repo} = 'git@github.com:elastic/built-docs.git' unless ( $Opts->{target_repo} );

    my $nginx_config = file('/tmp/nginx.conf');
    write_nginx_preview_config( $nginx_config );

    if ( my $nginx_pid = fork ) {
        my ( $repos_dir, $temp_dir, $reference_dir ) = init_dirs();

        my $target_repo;
        unless ( $Opts->{gapped} ) {
            say "Cloning built docs";
            $target_repo = init_target_repo( $repos_dir, $temp_dir, $reference_dir );
        }
        say "Built docs are ready";

        my $default_template = $Opts->{gapped} ? "air_gapped_template.html" : "template.html";
        my $preview_pid = start_preview(
            'git', '/docs_build/.repos/target_repo.git', $default_template, $Opts->{gapped}
        );
        $SIG{TERM} = sub {
            # We should be a good citizen and shut down the subprocesses.
            # This isn't so important in k8s or docker because we shoot
            # the entire container when we're done, but it is nice when
            # testing.
            say 'Terminating preview services...nginx';
            kill 'TERM', $nginx_pid;
            wait;
            say 'Terminating preview services...preview';
            kill 'TERM', $preview_pid;
            wait;
            say 'Terminated preview services';
            exit 0;
        };
        if ( $Opts->{gapped} ) {
            wait;
        } else {
            while (1) {
                sleep 1;
                my $fetch_result = eval { $target_repo->fetch };
                say $fetch_result if $fetch_result;
                say $@ if $@;
            }
        }
        exit;
    } else {
        close STDIN;
        open( STDIN, "</dev/null" );
        exec( qw(nginx -c), $nginx_config );
    }
}

#===================================
sub push_changes {
#===================================
    my ($build_dir, $target_repo, $tracker ) = @_;

    my $outstanding = $target_repo->outstanding_changes;
    if ( $tracker->has_non_local_changes || $outstanding ) {
        say "Saving branch tracker";
        $tracker->write;
        say "Building sitemap";
        build_sitemap( $build_dir, $outstanding );
        say "Commiting changes";
        $target_repo->commit;
        say "Pushing changes";
        $target_repo->push_changes;
        if ( $Opts->{announce_preview} ) {
            say "A preview will soon be available at " .
                $Opts->{announce_preview};
        }
    } else {
        say "No changes to push";
    }
}

#===================================
sub init_env {
#===================================
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

    if ( $Opts->{preview} ) {
        # `--preview` is run in k8s it doesn't *want* a tty
        # so it should avoid doing housekeeping below.
        return;
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

#===================================
sub pick_conf {
#===================================
    return file( 'conf.yaml' ) unless $Opts->{conf};

    my $conf = file($Opts->{conf});
    $conf = dir($Old_Pwd)->file($Opts->{conf}) if $conf->is_relative;
    return $conf if -e $conf;
    die "$conf doesn't exist";
}

#===================================
# Serve the documentation that we just built.
#
# docs_dir        - directory containing generated docs : Path::Class::dir
# redirects_file  - file containing redirects or 0 if there aren't
#                 - any redirects : Path::Class::file||0
# web_resources_pid - pid of a subprocess that rebuilds the web resources on
#                     the fly if we're running one or 0
# preview_pid     - pid of the preview application or 0 if we're not running it
#===================================
sub serve_local_preview {
#===================================
    my ( $docs_dir, $redirects_file, $web_resources_pid, $preview_pid ) = @_;

    if ( my $nginx_pid = fork ) {
        # parent
        $SIG{INT} = sub {
            say 'Terminating preview services...nginx';
            kill 'TERM', $nginx_pid;
            wait;
            if ( $preview_pid ) {
                say 'Terminating preview services...preview';
                kill 'TERM', $preview_pid;
                wait;
            }
            if ( $web_resources_pid ) {
                say 'Terminating preview services...parcel';
                kill 'TERM', $web_resources_pid;
                wait;
            }
        };
        $SIG{TERM} = $SIG{INT};

        wait;
        say 'Terminated preview services';
        exit;
    } else {
        my $nginx_config = file('/tmp/nginx.conf');
        write_nginx_test_config(
            $nginx_config, $docs_dir, $redirects_file,
            $web_resources_pid, $preview_pid
        );
        close STDIN;
        open( STDIN, "</dev/null" );
        exec( qw(nginx -c), $nginx_config );
    }
}

#===================================
sub command_line_opts {
#===================================
    return [
        # Options only compatible with --doc
        'doc=s',
        'alternatives=s@',
        'chunk=i',
        'lang=s',
        'lenient',
        'out=s',
        'resource=s@',
        'respect_edit_url_overrides',
        'single',
        'suppress_migration_warnings',
        'toc',
        'private',
        # Options only compatible with --all
        'all',
        'announce_preview=s',
        'target_branch=s',
        'target_repo=s',
        'keep_hash',
        'linkcheckonly',
        'push',
        'rebuild',
        'reference=s',
        'reposcache=s',
        'skiplinkcheck',
        'warnlinkcheck',
        'sub_dir=s@',
        'user=s',
        # Options only compatible with --preview
        'preview',
        'gapped',
        # Options that do *something* for either --doc or --all or --preview
        'asciidoctor',
        'conf=s',
        'direct_html',
        'in_standard_docker',
        'open',
        'procs=i',
        'verbose',
    ];
}

#===================================
sub usage {
#===================================
    say <<USAGE;

    Build local docs:

        build_docs --doc path/to/index.asciidoc [opts]

        Opts:
          --chunk 1         Also chunk sections into separate files
          --alternatives <source_lang>:<alternative_lang>:<dir>
                            Examples in alternative languages.
          --lang            Defaults to 'en'
          --lenient         Ignore linking errors
          --out dest/dir/   Defaults to ./html_docs.
          --resource        Path to image dir - may be repeated
          --respect_edit_url_overrides
                            Respects `:edit_url:` overrides in the book.
          --single          Generate a single HTML page, instead of
                            a chunking into a file per chapter
          --suppress_migration_warnings
                            Suppress warnings about Asciidoctor migration
                            issues. Use this when building "old" branches.
          --toc             Include a TOC at the beginning of the page.
          --private         Indicate that the github repo is private.
        WARNING: Anything in the `out` dir will be deleted!

    Build docs from all repos in conf.yaml:

        build_docs --all [opts]

        Opts:
          --keep_hash       Build docs from the same commit hash as last time
          --linkcheckonly   Skips the documentation builds. Checks links only.
          --push            Commit the updated docs and push to origin
          --announce_preview <host>
                            Causes the build to log a line about where to find
                            a preview of the build if anything is pushed.
          --rebuild         Rebuild all branches of every book regardless of
                            what has changed
          --reference       Directory of `--mirror` clones to use as a
                            local cache
          --repos_cache     Directory to which working repositories are cloned.
                            Defaults to `<script_dir>/.repos`.
          --skiplinkcheck   Omit the step that checks for broken links
          --warnlinkcheck   Checks for broken links but does not fail if they exist
          --sub_dir         Use a directory as a branch of some repo
                            (eg --sub_dir elasticsearch:master:~/Code/elasticsearch)
          --target_repo     Repository to which to commit docs
          --target_branch   Branch to which to commit docs
          --user            Specify which GitHub user to use, if not your own

    General Opts:
          --asciidoctor     Emit a happy message.
          --conf <ymlfile>  Use your own configuration file, defaults to the
                            bundled conf.yaml
          --direct_html     Emit a happy message.
          --in_standard_docker
                            Specified by build_docs when running in
                            its container
          --open            Open the docs in a browser once built.
          --procs           Number of processes to run in parallel, defaults
                            to 3
          --verbose         Output more logs
USAGE
}

#===================================
sub check_opts {
#===================================
    if ( !$Opts->{doc} ) {
        die('--alternatives only compatible with --doc') if $Opts->{alternatives};
        die('--chunk only compatible with --doc') if $Opts->{chunk};
        # Lang will be 'en' even if it isn't specified so we don't check it.
        die('--lenient only compatible with --doc') if $Opts->{lenient};
        die('--out only compatible with --doc') if $Opts->{out};
        die('--resource only compatible with --doc') if $Opts->{resource};
        die('--respect_edit_url_overrides only compatible with --doc') if $Opts->{respect_edit_url_overrides};
        die('--single only compatible with --doc') if $Opts->{single};
        die('--toc only compatible with --doc') if $Opts->{toc};
        die('--private only compatible with --doc') if $Opts->{private};
    }
    if ( !$Opts->{all} ) {
        die('--keep_hash only compatible with --all') if $Opts->{keep_hash};
        die('--linkcheckonly only compatible with --all') if $Opts->{linkcheckonly};
        die('--push only compatible with --all') if $Opts->{push};
        die('--announce_preview only compatible with --all') if $Opts->{announce_preview};
        die('--rebuild only compatible with --all') if $Opts->{rebuild};
        die('--reposcache only compatible with --all') if $Opts->{reposcache};
        die('--skiplinkcheck only compatible with --all') if $Opts->{skiplinkcheck};
        die('--warnlinkcheck only compatible with --all') if $Opts->{warnlinkcheck};
        die('--sub_dir only compatible with --all') if $Opts->{sub_dir};
    }
    if ( !$Opts->{preview} ) {
        die('--gapped only compatible with --preview') if $Opts->{gapped};
    }
    if ( !$Opts->{all} && !$Opts->{preview} ) {
        die('--reference only compatible with --all or --preview') if $Opts->{reference};
        die('--target_repo only compatible with --all or --preview') if $Opts->{target_repo};
    }
    if ($Opts->{skiplinkcheck} && $Opts->{warnlinkcheck} ) {
        die('--warnlinkcheck is incompatible with --skiplinkcheck');
    }
}
