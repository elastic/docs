#!/usr/bin/env perl

use strict;
use warnings;

our ( $Base_URL, $es, $Site_Index );

use FindBin;

BEGIN {
    chdir "$FindBin::RealBin/..";
    do "web/base.pl" or die $@;
}

use Proc::PID::File;
die "$0 already running\n" if Proc::PID::File->running( dir => '.run' );

use ES::Util();

our $name = shift(@ARGV)
    || die "USAGE: $0 index_name\n";

init_index($name);

#===================================
sub init_index {
#===================================
    my $alias = shift;
    if ( $es->indices->exists( index => $alias ) ) {
        print "Index ($alias) already exists\n";
        return;
    }

    my $index = create_index($alias);
    switch_alias( $alias, $index );

}
