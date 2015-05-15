#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;

our ($Old_Pwd);

use Cwd;
use FindBin;

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

init_env();

our $Conf = LoadFile('conf.yaml');

GetOptions(
    $Opts,    #
    'all', 'push',    #
    'single', 'doc=s', 'out=s', 'toc', 'chunk=i', 'toc_level=i', 'comments',
    'open',   'web',
    'lenient', 'verbose', 'reload_template'
);

$Opts->{template} = ES::Template->new(
    %{ $Conf->{template} },
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
    my $html;
    if ( $Opts->{single} ) {
        $dir->rmtree;
        $dir->mkpath;
        build_single( $index, $dir, %$Opts );
        $html = $index->basename;
        $html =~ s/\.[^.]+$/.html/;
    }
    else {
        build_chunked( $index, $dir, %$Opts );
        $html = 'index.html';
    }

    $html = $dir->file($html);

    say "Done";
    if ( $Opts->{web} ) {
        if ( my $pid = fork ) {

            # parent
            $SIG{INT} = sub {
                kill -9, $pid;
            };
            if ( $Opts->{open} ) {
                sleep 1;
                open_browser( 'http://localhost:8000/' . $html->basename );
            }

            wait;
            print "\nExiting\n";
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
    elsif ( $Opts->{open} ) {
        say "Opening: $html";
        open_browser($html);
    }
    else {
        say "See: $html";
    }
}

#===================================
sub build_all {
#===================================
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

    my $links = ES::LinkCheck->new($build_dir);

    for ( @{ $Conf->{extra_links} } ) {
        my $repo = ES::Repo->get_repo( $_->{repo} );
        my $file = $repo->dir->file( $_->{file} );
        say "Checking links in: $file";
        $links->check_file($file);
    }

    if ( $links->check ) {
        say $links->report;
    }
    else {
        die $links->report;
    }

    push_changes($build_dir)
        if $Opts->{push};
}

#===================================
sub build_entries {
#===================================
    my ( $build, $toc, @entries ) = @_;

    while ( my $entry = shift @entries ) {
        my $title = $entry->{title}
            or die "Missing title for entry: " . Dumper($entry);

        if ( my $sections = $entry->{sections} ) {
            my $section_toc = ES::Toc->new($title);
            $toc->add_entry($section_toc);
            build_entries( $build, $section_toc, @$sections );
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
<?xml version="1.0" encoding="UTF-8"?><?xml-stylesheet type="text/xsl" href="http://www.elastic.co/main-sitemap.xsl"?>
<urlset xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1" xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd" xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
SITEMAP_START

    $dir->recurse(
        callback => sub {
            my $item = shift;

            if ( $item->is_dir ) {
                return $item->PRUNE
                    if $item->basename eq 'images';
                return;
            }
            return unless $item->basename =~ /\.html$/;
            return $item->PRUNE unless $item->parent->basename eq 'current';
            my $date = timestamp( ( stat($item) )[9] );
            my $url = 'https://www.elastic.co/guide/' . $item->relative($dir);
            say $fh <<ENTRY;
<url>
    <loc>$url</loc>
    <lastmod>$date</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
</url>
ENTRY
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

    $repos_dir = dir($repos_dir);
    $repos_dir->mkpath;

    my $conf = $Conf->{repos}
        or die "Missing <repos> in config";

    my @repo_names = sort keys %$conf;

    my $tracker_path = $Conf->{paths}{branch_tracker}
        or die "Missing <paths.branch_tracker> in config";

    my $tracker = ES::BranchTracker->new( file($tracker_path), @repo_names );

    for my $name (@repo_names) {
        my $repo = ES::Repo->new(
            name    => $name,
            dir     => $repos_dir,
            tracker => $tracker,
            %{ $conf->{$name} }
        );
        $repo->update_from_remote();
    }

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
    chdir($FindBin::RealBin) or die $!;

    $ENV{SGML_CATALOG_FILES} = $ENV{XML_CATALOG_FILES} = join ' ',
        file('resources/docbook-xsl-1.78.1/catalog.xml')->absolute,
        file('resources/docbook-xml-4.5/catalog.xml')->absolute;

    $ENV{PATH}
        = dir('resources/asciidoc-8.6.8/')->absolute . ':' . $ENV{PATH};

    eval { run( 'xsltproc', '--version' ) }
        or die "Please install <xsltproc>";
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
          --chunk=1         Also chunk sections into separate files
          --toc_level=1     How many sections deep should the main ToC display
          --comments        Make // comments visible

          --open            Open the docs in a browser once built.
          --web             Serve the docs via a webserver once built.
          --lenient         Ignore linking errors
          --reload_template Force retrieving the latest web template
          --verbose

        WARNING: Anything in the `out` dir will be deleted!

    Build docs from all repos in conf.yaml:

        $0 --all [opts]

        Opts:
          --push            Commit the updated docs and push to origin
          --verbose

USAGE
}
