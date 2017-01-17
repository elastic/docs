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

our ( $Guide_Prefix, $Site_Index, $Docs_Index, $Titles_Index, $es );

say "Indexing titles";
main();

#===================================
sub main {
#===================================
    my $index = create_index($Titles_Index);
    my $b     = $es->bulk_helper( index => $index, type => 'doc' );
    my $s     = $es->scroll_helper( index => [ $Docs_Index, $Site_Index ] );

    eval {

        while ( my $doc = $s->next ) {
            my $url  = $doc->{_id};
            my %base = %{ $doc->{_source} };
            delete @base{ "content", "part_titles", "part" };
            if ( $doc->{_source}{part} ) {
                for ( @{ $doc->{_source}{part} } ) {
                    my $part_url = $url.$_->{id};
                    $b->add_action(
                        index => {
                            _id     => $part_url,
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
                $b->add_action(
                    index => {
                        _id     => $url,
                        _source => { %base, title => $doc->{_source}{title}, }
                    }
                );
            }
        }

        my $result = $b->flush;
        die "Error indexing titles: $result"
            if $result->{errors};
        $es->indices->forcemerge( index => $index, max_num_segments => 1 );
        1;

    } or do {
        my $error = $@;
        $es->indices->delete( index => $index );
        die $error;
    };

    switch_alias( $Titles_Index, $index );
}
