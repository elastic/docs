#!/usr/bin/env perl

use strict;
use warnings;
use POE;

my $bot = ES::Bot->new(

    server   => "holmes.freenode.net",
    port     => "6667",
    channels => ["#elasticsearch"],

    nick => "searchme",

    username => "searchme",
    password => $ENV{IRC_PASSWORD},
    name     => "ElasticSearch document search",

    search_url => 'http://localhost/search',
    search_book =>
        'http://www.elastic.co/guide/en/elasticsearch/reference/current',
    doc_max_results => 2,
);

$bot->run();

#===================================
package ES::Bot;
#===================================

use HTTP::Tiny;
use URI;
use JSON::XS qw(decode_json);
use parent 'Bot::BasicBot';

#===================================
sub help {
#===================================
    my $nick = shift->nick;
    <<HELP
Type "$nick: any keywords" to search the Elasticsearch docs
HELP
}

#===================================
sub said {
#===================================
    my $self = shift;
    my $msg  = shift;
    return if $msg->{who} && $msg->{who} eq 'NickServ';

    my $address = $msg->{address} || '';
    my $body = $msg->{body} // return;

    return unless $address eq 'msg' || $address eq $self->nick;
    return $self->reply( $msg, $self->docs($body) );
}

#===================================
sub docs {
#===================================
    my $self     = shift;
    my $keywords = shift;

    return "Nothing to search"
        unless defined $keywords && length $keywords;

    my $u = URI->new( $self->{search_url} );
    $u->query_form( book => $self->{search_book}, q => $keywords );

    my $results = eval { decode_json( HTTP::Tiny->new->get($u)->{content} ); };

    return _format_results( @{ $results->{book}{hits} }[ 0 .. 2 ] )
        if $results;

    my $error = $@ || 'Unknown error';
    if ( ref $error and $error->isa('Elasticsearch::Error::Request') ) {
        return "Sorry, didn't understand that search";
    }
    $error = substr( $error, 0, 50 );
    return "Hmm, problem - couldn't search: $error";

}

#===================================
sub _format_results {
#===================================
    my @results;
    return "No results found" unless @_;
    while ( my $doc = shift @_ ) {
        my $url = $doc->{url};
        push @results, ' http://elastic.co' . $url;
    }
    return join "\n", "Try these urls:", @results;
}

1;

