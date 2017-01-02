#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;
use utf8;

use FindBin;

BEGIN {
    chdir "$FindBin::RealBin/..";
    do "web/base.pl" or die $@;
}

use Proc::PID::File;
die "$0 already running\n" if Proc::PID::File->running( dir => '.run' );

our ( $Guide_Prefix, $Docs_Index, $es );

use YAML qw(LoadFile);
use Path::Class qw(dir file);
use Encode qw(decode_utf8);
use ES::Util qw(run $Opts sha_for);
use ES::DocsParser();
use Getopt::Long;

our $Conf = LoadFile('conf.yaml');

GetOptions( $Opts, 'force' );

if ( !$Opts->{force} and sha_for("HEAD") eq sha_for('_index') ) {
    say "Up to date";
    exit;
}

say "Indexing docs";
main();
run qw(git branch -f _index HEAD);

#===================================
sub main {
#===================================
    my $dir = $Conf->{paths}{build}
        or die "Missing <paths.build> from config";
    $dir = dir($dir);

    my $index = create_index($Docs_Index);

    my @docs;
    eval {
        for my $book ( books( '', @{ $Conf->{contents} } ) ) {
            say "Indexing book: $book->{title}";
            my $b = $es->bulk_helper(
                index     => $index,
                type      => 'doc',
                max_count => 100
            );

            my $current
                = $book->{current};
            my @docs = index_docs( $b, $dir, $book->{prefix}, $book->{tags},
                $book->{single}, $current );

            my $result = $b->flush;

            die join "\n", "Error indexing $book->{title}:",
                map { $_->{error} } @{ $result->{errors} }
                if $result->{errors};
        }

        $es->indices->forcemerge( index => $index, max_num_segments => 1 );
        1;
    } or do {
        my $error = $@;
        $es->indices->delete( index => $index );
        die $error;
    };
    switch_alias( $Docs_Index, $index );
}

#===================================
sub index_docs {
#===================================
    my ( $bulk, $dir, $prefix, $tags, $single, $current ) = @_;

    my $length_dir = length($dir);
    my $book_dir   = $dir->subdir($prefix);
    my @versions   = grep { $_->is_dir && $_->basename ne 'current' }
        $book_dir->children();

    for my $version_dir (@versions) {

        my $version = $version_dir->basename;
        my $is_current = $version eq $current ? \1 : \0;

        my @files;
        my $toc = $version_dir->file('toc.html');
        if ( -e $toc ) {
            my $content = $toc->slurp( iomode => "<:encoding(UTF-8)" );
            @files = ( $content =~ /href="([^"]+)"/g );
        }
        else {
            @files = 'index.html';
        }

        my $section
            = @versions > 1
            ? 'Docs/' . $tags . '/' . $version
            : 'Docs/' . $tags;

        my ( $product, $book_title ) = split '/', $tags;

        for (@files) {
            my $file = $version_dir->file($_);
            my $url = $Guide_Prefix . substr( $file, $length_dir );

            for my $page ( _load_file( $file, $single ) ) {

                # single-page books don't have their titles detected
                $page->{title} ||= $book_title;
                $page->{breadcrumbs} ||= $book_title;

                $bulk->index(
                    {   _id     => $url,
                        _source => {
                            %$page,
                            url        => $url,
                            tags       => $product,
                            section    => $section,
                            is_current => $is_current,
                        }
                    }
                );
            }
        }
    }
    return;
}

#===================================
sub _load_file {
#===================================
    my ( $file, $single ) = @_;
    my $content = $file->slurp( iomode => '<:encoding(UTF-8)' );
    my $parser = ES::DocsParser->new;
    $parser->parse($content);
    my $output   = $parser->output;
    my $sections = $output->{sections};

    my %page = ( part => [] );
    unless ($single) {
        $page{title}       = $sections->[0]{title};
        $page{breadcrumbs} = $output->{breadcrumbs};
    }
    for my $section (@$sections) {
        next unless $section->{text};
        push @{ $page{part} },
            {
            title   => $section->{title},
            content => $section->{text},
            id      => $section->{id}
            };
    }
    return \%page;
}

#===================================
sub books {
#===================================
    my @books;
    my $base_dir = shift();
    while ( my $next = shift @_ ) {
        my $new_base_dir = $base_dir;
        if ( $next->{sections} ) {
            if ( $next->{base_dir} ) {
                $new_base_dir .= '/' . $next->{base_dir};
            }
            push @books, books( $new_base_dir, @{ $next->{sections} } );
        }
        else {
            my %details = %$next;
            if ($new_base_dir) {
                $details{prefix} = $new_base_dir . "/" . $details{prefix};
            }
            push @books, \%details;
        }
    }
    return @books;
}

#===================================
sub usage {
#===================================
    say <<USAGE;

    Index all generated HTML docs in the build directory

        $0 [opts]

        Opts:
          --force           Reindex the docs even if already up to date

USAGE
}
