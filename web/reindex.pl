#!/usr/bin/env perl

use strict;
use warnings;
use Search::Elasticsearch;
use JSON::XS;

our ($es);

use FindBin;

BEGIN {
    chdir "$FindBin::RealBin/..";
    do "web/base.pl" or die $@;
}

use Proc::PID::File;
die "$0 already running\n" if Proc::PID::File->running( dir => '.run' );

our $alias = shift(@ARGV)
    || die "USAGE: $0 index_name\n";

my $result = $es->indices->get_alias( index => $alias, ignore => 404 )
    or die "Index ($alias) doesn't exist\n";

my ($source) = keys %$result;
die "Index ($alias) does not exist\n" unless $source;
die "Index ($alias) is not associated with an alias\n"
    unless $result->{$source}{aliases};

my $index = create_index($alias);

print "Reindexing from ($source) to ($index)\n";

$es->reindex(
    body => { source => { index => $source }, dest => { index => $index } } );

print "\n";
switch_alias( $alias, $index );

