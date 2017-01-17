#!/usr/bin/env perl

use strict;
use warnings;
use HTML::Entities qw(decode_entities);

our ( $Base_URL, @Sitemap_Paths, $es, $Site_Index );
our $Procs = 12;
use FindBin;

BEGIN {
    chdir "$FindBin::RealBin/..";
    do "web/base.pl" or die $@;
}

use Proc::PID::File;
die "$0 already running\n" if Proc::PID::File->running( dir => '.run' );

use ES::Util qw(timestamp get_url proc_man);
use ES::SiteParser;

my $force        = @ARGV && $ARGV[0] =~ /^-f|--force/;
my $now          = timestamp();
my $sitemap_urls = get_sitemap( $Base_URL, @Sitemap_Paths );
my $known_urls   = get_known_urls($Site_Index);

index_changes( $Site_Index, $sitemap_urls, $known_urls );

#===================================
sub index_changes {
#===================================
    my ( $index, $new, $old ) = @_;
    my $bulk = $es->bulk_helper( index => $index, type => 'doc' );
    for ( keys %$old ) {
        if ( !$new->{$_} ) {
            $bulk->delete_ids($_);
            print "Deleting doc ($_)\n";
        }
        elsif ( !$force and $new->{$_} eq $old->{$_} ) {
            delete $new->{$_};
            print "Doc ($_) unchanged\n";
        }
    }
    $bulk->flush;

    my @entries;
    my $i = 0;
    for my $url ( keys %$new ) {
        push @{ $entries[ $i++ ] },
            { url => $url, published_at => $new->{url} };
        $i = $i % $Procs;
    }

    my $pm = proc_man($Procs);
    for ( 1 .. $Procs - 1 ) {
        $pm->start && next;
        index_urls( $index, $entries[$_] );
        $pm->finish;

    }
    $pm->wait_all_children;
    return keys(%$new) + keys(%$old);
}

#===================================
sub index_urls {
#===================================
    my ( $index, $urls ) = @_;
    my $bulk
        = $es->bulk_helper( index => $index, type => 'doc', max_docs => 100 );
    for (@$urls) {
        my ( $url, $published_at ) = @{$_}{ 'url', 'published_at' };
        print "Indexing ($url)\n";
        my $html = eval { get_url( $Base_URL . $url ) } || do {
            print "[WARN] $@";
            $bulk->delete_ids($url);
            print "Deleting doc ($url)\n";
            next;
        };

        my $parser = ES::SiteParser->new();
        $parser->parse($html);
        my $doc = $parser->output;
        $doc->{published_at} = $published_at;
        $doc->{title} =~ s/\s*\|\s*Elastic\s*$//;

        my @tags = @{ $doc->{tags} };
        my $section = $doc->{section} || '';

        if ( !$section && @tags == 0 ) {
            my $path = $url;

            # percent decoding
            $path =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

            # if first part of path begins with at least three letters
            if ( $path =~ m{^/([a-z]{3,}[^/]*)/}i ) {
                $section = $1;

                # uppercase first chars of each word
                $section =~ s{(_|\b)(\w)}{$1\u$2}g;
                $doc->{section} = $section;
            }
        }

        $doc->{tags}       = \@tags;
        $doc->{is_current} = \1;
        $doc->{url}        = $url;

        $bulk->index( { id => $url, source => $doc } );
    }
    $bulk->flush;

}

#===================================
sub get_sitemap {
#===================================
    my ( $hostname, @paths ) = @_;

    my %entries;

    for my $path (@paths) {
        my $sitemap = $hostname . $path;
        my $xml     = get_url($sitemap);
        my $count   = () = ( $xml =~ /<url>/g );
        die "No <url> elements found in the sitemap ($sitemap)\n"
            unless $count;

        pos($xml) = index( $xml, '<url>' );
        while ( $xml =~ m{\G<url>\s*(.+?)\s*</url>\s*}sg ) {
            my $entry = $1;
            my %vals;

            while ( $entry =~ m{\G<(\w+)>\s*([^<]+?)\s*</\1>\s*}sg ) {
                $vals{$1} = $2;
            }

            my $url = $vals{loc}
                or die "No <loc> found in: \n$entry\n";
            $url = URI->new( decode_entities($url) )->path;

            my $lastmod = $vals{lastmod} || $now;

            #        die "URL ($url) already exists in sitemap"
            #            if $entries{$url};
            $entries{$url} = $lastmod;
        }
    }

    #    die "Expecting $count URLs in sitemap ($sitemap) but only found "
    #        . ( keys %entries )
    #        if keys(%entries) != $count;
    return \%entries;

}

#===================================
sub get_known_urls {
#===================================
    my $index = shift;
    my %urls;
    my $scroll = $es->scroll_helper(
        index   => $index,
        type    => 'doc',
        size    => 1000,
        sort    => '_doc',
        _source => 'published_at'
    );
    while ( my $hit = $scroll->next ) {
        $urls{ $hit->{_id} } = $hit->{_source}{published_at};
    }
    return \%urls;
}
