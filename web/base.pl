#!/usr/bin/env perl

use strict;
use warnings;

use lib "lib";

use Search::Elasticsearch;
use JSON::XS;
use Path::Class qw(file);
our $JSON = JSON::XS->new->utf8->pretty;

our $ES_URLS = [ split /\s*,\s*/, $ENV{ES_URLS} || 'http://localhost:9200' ];
our $Site_Index = 'site';
our $Pages_Index   = 'pages';
our $Titles_Index  = 'titles';
our $Base_URL      = 'https://www.elastic.co/';
our @Sitemap_Paths = (
    { 'locale' => 'en', 'path' => '/sitemap.xml' },
    { 'locale' => 'cn', 'path' => '/sitemap-cn.xml' },
    { 'locale' => 'de', 'path' => '/sitemap-de.xml' },
    { 'locale' => 'fr', 'path' => '/sitemap-fr.xml' },
    { 'locale' => 'jp', 'path' => '/sitemap-jp.xml' },
    { 'locale' => 'kr', 'path' => '/sitemap-kr.xml' }
);
our $Guide_Prefix         = '/guide';
our $Max_Page             = 10;
our $Page_Size            = 15;
our $Max_Sections         = 10;
our $Max_Hits_Per_Section = 5;

our $es = Search::Elasticsearch->new(
    nodes           => $ES_URLS,
    client          => '5_0::Direct',
    request_timeout => 1000
);

#===================================
sub create_index {
#===================================
    my $name       = shift;
    my $index_name = $name . '_' . time();
    my $json       = file("web/config_$name.json")->slurp;
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
    my $aliases = $es->indices->get_alias( index => $alias, ignore => 404 );
    my @actions = { add => { index => $index, alias => $alias } };
    my @old = keys %$aliases;

    for (@old) {
        push @actions, { remove_index => { index => $_ } };
    }

    $es->indices->update_aliases( body => { actions => \@actions } );
    print "Switched alias <$alias> to <$index>\n";
}

1
