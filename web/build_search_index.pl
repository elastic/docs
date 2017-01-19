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

our ( $Guide_Prefix, $Pages_Index, $Site_Index, $Titles_Index, $es );
our $Procs = 3;

use YAML qw(LoadFile);
use Path::Class qw(dir file);
use Encode qw(decode_utf8);
use ES::Util qw(run $Opts sha_for proc_man);
use ES::DocsParser();
use Getopt::Long;

our $Conf = LoadFile('conf.yaml');

GetOptions( $Opts, 'force' );

if ( !$Opts->{force} and sha_for("HEAD") eq sha_for('_index') ) {
    say "Up to date";
    exit;
}

main();

#===================================
sub main {
#===================================
    my ( $pages_index, $titles_index );

    eval {
        say "Indexing docs";
        $pages_index = create_index($Pages_Index);
        index_docs($pages_index);

        say "";
        say "Indexing site";
        $es->reindex(
            body => {
                source => { index => $Site_Index },
                dest   => { index => $pages_index }
            }
        );
        $es->indices->refresh(index=>$pages_index);

        say "";
        say "Indexing titles";
        $titles_index = create_index($Titles_Index);
        index_titles($pages_index,$titles_index);

        say "";
        say "Putting indices live";
        deploy( $pages_index, $titles_index );

        say "Done";

        1;
    } or do {
        my $error = $@;
        eval {
            $es->indices->delete( index => $pages_index, ignore => '404' )
                if $pages_index;
            $es->indices->delete( index => $titles_index, ignore => '404' )
                if $titles_index;
            1;
        } || warn $@;
        die "Error building search index: $error";
    };
    run qw(git branch -f _index HEAD);
}

#===================================
sub deploy {
#===================================
    my ( $pages_index, $titles_index ) = @_;
    for (@_) {
        $es->indices->forcemerge(
            index            => $_,
            max_num_segments => 1
        );
        $es->indices->refresh( index => $_ );
    }

    my @current
        = keys
        %{ $es->indices->get_alias( name => [ $Titles_Index, $Pages_Index ] )
        };

    $es->indices->update_aliases(
        body => {
            actions => [
                { add => { index => $pages_index,  alias => $Pages_Index } },
                { add => { index => $titles_index, alias => $Titles_Index } },
                map { +{ remove_index => { index => $_ } } } @current
            ]
        }
    );
}

#===================================
sub index_titles {
#===================================
    my ( $pages_index, $titles_index ) = @_;

    my $b = $es->bulk_helper( index => $titles_index, type => 'doc' );
    my $s = $es->scroll_helper( index => $pages_index );

    while ( my $doc = $s->next ) {
        my $url  = $doc->{_id};
        my %base = %{ $doc->{_source} };
        delete @base{ "content", "part_titles", "part" };
        if ( $doc->{_source}{part} ) {
            for ( @{ $doc->{_source}{part} } ) {
                my $part_url = $url . $_->{id};
                $b->index(
                    {   _id     => $part_url,
                        _source => {
                            %base,
                            title => $_->{title},
                            url   => $part_url
                        }
                    }
                );
            }
        }
        else {
            $b->index(
                {   _id     => $url,
                    _source => { %base, title => $doc->{_source}{title}, }
                }
            );
        }
    }

    my $result = $b->flush;
    die join "\n", "Error indexing titles:",
        map { $_->{error} } @{ $result->{errors} }
        if $result->{errors};

}

#===================================
sub index_docs {
#===================================
    my $index = shift;
    my $dir   = $Conf->{paths}{build}
        or die "Missing <paths.build> from config";
    $dir = dir($dir);

    my $pm = proc_man(3);
    for my $book ( _books( '', @{ $Conf->{contents} } ) ) {
        $pm->start && next;
        _index_book( $index, $dir, $book );
        $pm->finish;
    }
    $pm->wait_all_children;
}

#===================================
sub _index_book {
#===================================
    my ( $index, $dir, $book ) = @_;

    say "Indexing book: $book->{title}";

    my $tags = $book->{tags};
    my ( $product, $book_title ) = split '/', $tags;

    my $length_dir = length($dir);
    my $book_dir   = $dir->subdir( $book->{prefix} );
    my $current    = $book->{current};
    my @versions = grep { $_->is_dir && $_->basename ne 'current' }
        $book_dir->children();

    my $bulk = $es->bulk_helper(
        index     => $index,
        type      => 'doc',
        max_count => 100
    );

    for my $version_dir (@versions) {

        my $version = $version_dir->basename;
        my @files   = _files_to_index($version_dir);
        my $section
            = @versions > 1
            ? 'Docs/' . $tags . '/' . $version
            : 'Docs/' . $tags;

        for my $file (@files) {
            my $url = $Guide_Prefix . substr( $file, $length_dir );

            for my $page ( _load_file( $file, $book->{single} ) ) {

                # single-page books don't have their titles detected
                $page->{title}       ||= $book_title;
                $page->{breadcrumbs} ||= $book_title;

                $bulk->index(
                    {   _id     => $url,
                        _source => {
                            %$page,
                            url        => $url,
                            tags       => $product,
                            section    => $section,
                            is_current => $version eq $current ? \1 : \0,
                        }
                    }
                );
            }
        }
    }

    my $result = $bulk->flush;

    die join "\n", "Error indexing $book->{title}:",
        map { $_->{error} } @{ $result->{errors} }
        if $result->{errors};

    return;
}

#===================================
sub _files_to_index {
#===================================
    my $version_dir = shift;
    my @files;
    my $toc = $version_dir->file('toc.html');
    if ( -e $toc ) {
        my $content = $toc->slurp( iomode => "<:encoding(UTF-8)" );
        @files = ( $content =~ /href="([^"]+)"/g );
    }
    else {
        @files = 'index.html';
    }
    return map { $version_dir->file($_) } @files;
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
sub _books {
#===================================
    my @books;
    my $base_dir = shift();
    while ( my $next = shift @_ ) {
        my $new_base_dir = $base_dir;
        if ( $next->{sections} ) {
            if ( $next->{base_dir} ) {
                $new_base_dir .= '/' . $next->{base_dir};
            }
            push @books, _books( $new_base_dir, @{ $next->{sections} } );
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
