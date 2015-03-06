#!/usr/bin/env perl

use strict;
use warnings;
use Encode qw(encode_utf8);
use Plack::Request;
use Plack::Builder;
use Plack::Response;
use Search::Elasticsearch;
use HTML::Entities qw(encode_entities decode_entities);
use JSON::XS;

our ( $es, $Docs_Index, $Site_Index, $Max_Page, $Page_Size );

use FindBin;

BEGIN {
    chdir "$FindBin::RealBin/..";
    do "web/base.pl" or die $!;
}

our $JSON           = JSON::XS->new->utf8->pretty;
our $Remove_Host_RE = qr{^https?://[^/]+/guide/};
our $Referer_RE     = qr{
    ^
    (.+?)                           # book
    (?:/(current|master|\d[^/]+))?  # version
    /[^/]+                          # remainder
    $}x;

builder {
    mount '/search'  => \&search;
    mount '/suggest' => \&suggest;
};

#===================================
sub suggest {
#===================================
    my $req = Plack::Request->new(@_);
    my $q = eval { $req->query_parameters->get_one('q') }
        or return _as_json( 200, { hits => [] } );

    my %request = _get_request( $q, 'suggest' );
    my $result = eval { $es->search(%request)->{hits} }
        or return _as_json( 500, { error => $@ } );

    return _as_json( 200, _format_hits($result) );
}

#===================================
sub search {
#===================================
    my $req = Plack::Request->new(@_);
    my $q = eval { $req->query_parameters->get_one('q') }
        or return _as_json( 200, { hits => [] } );

    my $page = eval { $req->query_parameters->get_one('page') } || 1;
    $page = $Max_Page if $page > $Max_Page;

    my $ref
        = eval { $req->query_parameters->get_one('book') }
        || ( $page == 1 and $req->headers->referer )
        || '';

    my ( $book, $version );
    if ($ref) {
        $ref =~ s/$Remove_Host_RE//;
        if ( $ref =~ /$Referer_RE/ ) {
            $book    = $1;
            $version = $2;
        }
    }

    my @requests;
    if ( $page == 1 or not $book ) {
        push @requests, _to_msearch( _get_request( $q, 'search', $page ) );
    }

    if ($book) {
        push @requests,
            _to_msearch( _get_request( $q, 'search', $page, $book, $version ) );
    }

    my $response = eval { $es->msearch( body => \@requests )->{responses} }
        or return _as_json( 500, { error => $@ } );

    my %results;
    if ($book) {
        $results{book}
            = _format_hits( pop(@$response)->{hits}, $page, $q, $ref );
    }

    if (@$response) {
        $results{site} = _format_hits( pop(@$response)->{hits}, $page, $q );
    }
    return _as_json( 200, \%results );
}

#===================================
sub _format_hits {
#===================================
    my $results = shift;
    my @hits;

    for ( @{ $results->{hits} } ) {
        my %hit = (
            url   => $_->{_id},
            title => encode_entities( $_->{_source}{title}, '<>&"' )
        );
        if ( my $highlight = $_->{highlight}{"content"} ) {
            $hit{highlight} = _format_highlights($highlight);
        }
        push @hits, \%hit;
    }

    my %response = ( hits => \@hits, total => $results->{total} );
    if ( my $page = shift ) {
        my $q    = shift;
        my $book = shift;
        my @pages;
        my $last_page = int( $results->{total} / $Page_Size ) + 1;
        $last_page = $Max_Page if $Max_Page < $last_page;

        for ( 1 .. $last_page ) {
            if ( $page == $_ ) {
                push @pages, { page => $_, current => 1 };
            }
            else {
                push @pages,
                    {
                    page => $_,
                    q    => $q,
                    $book ? ( book => $book ) : ()
                    };
            }
        }
        $response{pages} = \@pages;
    }
    return \%response;
}

#===================================
sub _get_request {
#===================================
    my ( $q, $type, $page, $book, $version ) = @_;

    $version ||= 'current';
    $page    ||= 1;

    my ( $filter, @index, @fields, $highlight );

    my @functions = (
        {   filter => { term => { is_section => 'true' } },
            weight => 0.9
        }
    );

    if ($book) {
        @index  = $Docs_Index;
        $filter = {
            bool => {
                must => [
                    { term => { book    => $book } },
                    { term => { version => $version } }
                ]
            }
        };

    }
    else {
        @index = ( $Docs_Index, $Site_Index );
        $filter = {
            bool => {
                should => [
                    { missing => { field   => 'version' } },
                    { term    => { version => $version } }
                ],
            }
        };

        push @functions,
            (
            {   filter => { term => { tags => 'Clients' } },
                weight => 0.9
            },
            {   filter => { term => { tags => 'Elasticsearch' } },
                weight => 1.1
            },
            );
    }

    if ( $type eq 'suggest' ) {
        @fields = (
            "title^2",       "title.shingles",
            "title.stemmed", 'title.autocomplete'
        );
    }
    else {
        @fields = (
            "title^3",         "title.shingles^2",
            "title.stemmed^2", 'title.autocomplete',
            'content',         'content.shingles',
            'content.stemmed', 'content.autocomplete'
        );
        $highlight = {
            pre_tags  => ['[[['],
            post_tags => [']]]'],
            fields    => {
                "content" => {
                    fragment_size       => 150,
                    number_of_fragments => 2,
                    highlight_query     => { match => { "content" => $q } }
                },
            }
        };
    }

    return (
        index => \@index,
        body  => {
            _source => ['title'],
            size    => $Page_Size,
            from    => ( $page - 1 ) * $Page_Size,
            query   => {
                function_score => {
                    query => {
                        filtered => {
                            query => {
                                multi_match => {
                                    type                 => 'most_fields',
                                    query                => $q,
                                    minimum_should_match => "80%",
                                    fields               => \@fields
                                }
                            },
                            filter => $filter
                        }
                    },
                    functions  => \@functions,
                    score_mode => 'multiply'
                }
            },
            highlight => $highlight || {}
        }
    );
}

#===================================
sub _to_msearch {
#===================================
    my %args = @_;
    my $body = delete $args{body};
    return ( \%args, $body );
}

#===================================
sub _format_highlights {
#===================================
    my $highlights = shift;
    my @snippets;
    for my $snippet (@$highlights) {
        $snippet = encode_entities( $snippet, '<>&"' );
        $snippet =~ s/\[{3}/<em>/g;
        $snippet =~ s!\]{3}!</em>!g;
        $snippet =~ s/\s*\.\s*$//;
        push @snippets, $snippet;
    }
    return join " ... ", @snippets

}

#===================================
sub _as_json {
#===================================
    my ( $code, $data ) = @_;
    return [
        $code,
        [ 'Content-Type' => 'application/json' ],
        [ $JSON->encode($data) ]
    ];
}

#===================================
sub _as_text {
#===================================
    my ( $code, $text ) = @_;
    return [ $code, [ 'Content-Type' => 'text/plain' ], [$text] ];
}

