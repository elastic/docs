#!/usr/bin/env perl

use strict;
use warnings;

use lib "lib";

use Search::Elasticsearch;
use JSON::XS;
use Path::Class qw(file);
our $JSON = JSON::XS->new->utf8->pretty;

our $Site_Index   = 'site';
our $Docs_Index   = 'docs';
our $Base_URL     = 'https://www.elastic.co/';
our $Sitemap_Path = '/sitemap.xml';
our $Guide_Prefix = '/guide';
our $Max_Page     = 10;
our $Page_Size    = 15;

our $es = Search::Elasticsearch->new( nodes => 'http://localhost:9200' );

#===================================
sub create_index {
#===================================
    my $name       = shift;
    my $index_name = $name . '_' . time();
    my $json       = file("web/$name.json")->slurp;
    my $defn       = $JSON->decode($json);
    $es->indices->create(
        index => $index_name,
        body  => $defn
    );
    print "Created index <$index_name>\n";
    return $index_name;
}

#===================================
sub switch_alias {
#===================================
    my ( $alias, $index ) = @_;
    my $aliases = $es->indices->get_alias( index => $alias );
    my @actions = { add => { index => $index, alias => $alias } };
    my @old = keys %$aliases;

    for (@old) {
        push @actions, { remove => { alias => $alias, index => $_ } };
    }

    $es->indices->update_aliases( body => { actions => \@actions } );
    $es->indices->delete( index => \@old ) if @old;
    print "Switched alias <$alias> to <$index>\n";
}

