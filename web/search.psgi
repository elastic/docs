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

our ( $es, $Docs_Index, $Site_Index, $Titles_Index, $Max_Page, $Page_Size,
    $Max_Sections, $Max_Hits_Per_Section );

use FindBin;

BEGIN {
    chdir "$FindBin::RealBin/..";
    do "web/base.pl" or die $@;
}

our $JSON = JSON::XS->new->utf8;

builder {
    mount '/search'  => \&search;
    mount '/suggest' => \&suggest;
};

#===================================
sub _parse_request {
#===================================
    my $req     = Plack::Request->new(@_);
    my $qs      = $req->query_parameters;
    my $q       = eval { $qs->get_one('q') } || '';
    my $section = eval { $qs->get_one('section') } || '';
    my @tags    = grep {$_} $qs->get_all('tags');
    my $page    = eval { $qs->get_one('page') } || 1;

    $q =~ s/^\s+//;
    $q =~ s/\s$//;

    return unless $q || $section || @tags;

    my %query = (
        q       => $q,
        section => $section,
        tags    => \@tags,
        page    => $page,
    );

    if ( $section =~ /^Docs/ ) {
        my ( undef, $product, $book, $version ) = split /\//, $section;
        $query{docs} = {
            product => $product,
            book    => $book,
            version => $version
        };
    }
    return \%query;
}

#===================================
sub search {
#===================================
    my $q = _parse_request(@_) or return _as_json( 200, {} );

    my $page = $q->{page} > $Max_Page ? $Max_Page : $q->{page};

    my $request = {
        from => ( $page - 1 ) * $Page_Size,
        size => $Page_Size,
    };

    _add_search_query( $request, $q );

    # return _as_json( 200, $request );
    return _run_request( [ $Docs_Index, $Site_Index ], $request );
}

#===================================
sub suggest {
#===================================
    my $q = _parse_request(@_) or return _as_json( 200, {} );

    return _as_json( 200, {} )
        unless $q->{q};

    my $request = {
        from => 0,
        size => $Page_Size,
    };

    _add_suggest_query( $request, $q );

    # return _as_json( 200, $request );
    return _run_request( $Titles_Index, $request );
}

#===================================
sub _add_search_query {
#===================================
    my ( $request, $q ) = @_;

    my ( @filter, @must, @should );

    $request->{query} = {
        bool => {
            must   => \@must,
            should => \@should,
            filter => \@filter
        }
    };
    $request->{_source} = [qw(url title breadcrumbs)];

    push @filter, (
        _section_filter($q),    #
        _tags_filter($q),       #
        _current_filter($q)
    );

    my $text = $q->{q};
    unless ($text) {
        push @filter, { exists => { field => 'published_at' } };
        $request->{sort} = [
            {   "published_at" => {
                    order         => 'desc',
                    missing       => '_last',
                    unmapped_type => 'date'
                }
            }
        ];
        return $request;
    }

    push @must,
        {
        "multi_match" => {
            "fields" => [
                "title.stemmed^3", "part_titles.stemmed^1.5",
                "content.stemmed"
            ],
            "minimum_should_match" => "2<80%",
            "query"                => $text,
            "type"                 => "best_fields",
            "tie_breaker"          => 0.2,
            "fuzziness"            => "auto",
        }
        };

    push @should,
        {
        "dis_max" => {
            "boost"       => 2,
            "tie_breaker" => 0.3,
            "queries"     => [
                {   "multi_match" => {
                        "query"  => $text,
                        "type"   => "most_fields",
                        "boost"  => 1.5,
                        "fields" => [ "title^1.5", "title.shingles", ]
                    }
                },
                {   "multi_match" => {
                        "query" => $text,
                        "type"  => "most_fields",
                        "boost" => 1.2,
                        "fields" =>
                            [ "part_titles^1.5", "part_titles.shingles" ]
                    }
                },
                {   "multi_match" => {
                        "query"  => $text,
                        "type"   => "most_fields",
                        "fields" => [ "content^1.5", "content.shingles" ]
                    }
                }
            ]
        }
        };

    push @should,
        {
        "nested" => {
            "score_mode" => "none",
            "path"       => "part",
            "inner_hits" => {
                "size"      => 4,
                "_source"   => { "includes" => [ "part.id", "part.title" ] },
                "highlight" => _highlight("part.content.stemmed")
            },
            "query" => {
                "dis_max" => {
                    "tie_breaker" => 0.3,
                    "queries"     => [
                        {   "multi_match" => {
                                "query"  => $text,
                                "type"   => "most_fields",
                                "boost"  => 1.5,
                                "fields" => [
                                    "part.title^1.5",
                                    "part.title.stemmed",
                                    "part.title.shingles",
                                ]
                            }
                        },
                        {   "multi_match" => {
                                "query"  => $text,
                                "type"   => "most_fields",
                                "fields" => [
                                    "part.content^1.5",
                                    "part.content.stemmed",
                                    "part.content.shingles",
                                ]
                            }
                        }
                    ]
                }
            }
        }
        };

    $request->{sort} = [
        '_score',
        {   "published_at" => {
                order         => 'desc',
                missing       => '_last',
                unmapped_type => 'date'
            }
        }
    ];
    $request->{highlight} = _highlight('content.stemmed');
}

#===================================
sub _add_suggest_query {
#===================================
    my ( $request, $q ) = @_;

    my ( @filter, @must, @should );

    $request->{query} = {
        bool => {
            must   => \@must,
            should => \@should,
            filter => \@filter
        }
    };
    $request->{_source}   = [qw(url breadcrumbs )];
    $request->{highlight} = _highlight("title.autocomplete");

    push @filter, (
        _section_filter($q),    #
        _tags_filter($q),       #
        _current_filter($q)
    );

    my $text = $q->{q};
    push @must,
        {
        "match" => {
            "title.autocomplete" => {
                "minimum_should_match" => "2<80%",
                "fuzziness"            => 'auto',
                "query"                => $text,
            }
        }
        };

    push @should,
        {
        "multi_match" => {
            "query"  => $text,
            "type"   => "most_fields",
            "boost"  => 1.5,
            "fields" => [ "title^1.5", "title.shingles" ]
        }
        };

    $request->{sort} = [
        '_score',
        {   "published_at" => {
                order         => 'desc',
                missing       => '_last',
                unmapped_type => 'date'
            }
        }
    ];
}

#===================================
sub _current_filter {
#===================================
    my $q = shift;
    return if $q->{docs}{version};
    return { term => { is_current => \1 } };
}

#===================================
sub _section_filter {
#===================================
    my $q = shift;
    my $section = $q->{section} or return;
    return { term => { section => $section } };
}

#===================================
sub _tags_filter {
#===================================
    my $q = shift;
    if ( @{ $q->{tags} } ) {
        my @filters = map { +{ term => { tags => $_ } } } @{ $q->{tags} };
        return { bool => { filter => \@filters } };
    }
    return;
}

#===================================
sub _highlight {
#===================================
    my $field = shift;
    return {
        "type"                => "postings",
        "number_of_fragments" => 4,
        "no_match_size"       => 300,
        "fragment_size"       => 300,
        pre_tags              => ['[[['],
        post_tags             => [']]]'],
        "fields"              => { $field => {} }
    };
}

#===================================
sub _explain {
#===================================
    my $results = shift;
    for ( @{ $results->{hits}{hits} } ) {
        _explain_hit($_);
    }
}

#===================================
sub _explain_hit {
#===================================
    my $hit = shift;

    my $explain = $hit->{_explanation}
        || return;

    my @text = sprintf "Doc: [%s|%s|%s], Shard: [%s|%s]:\n",
        map { defined $_ ? $_ : 'undef' }
        @{$hit}{qw(_index _type _id _node _shard)};

    my $indent = 0;
    my @stack  = [$explain];
    while (@stack) {
        my @current = @{ shift @stack };
        while ( my $next = shift @current ) {
            my $spaces = ( ' ' x $indent ) . ' - ';
            my $desc   = $next->{description};
            if ( $desc =~ /^score/ ) {
                delete $next->{details};
            }
            $desc =~ s/\n//g;
            push @text, sprintf "%-100s | % 9.4f\n", $spaces . $desc,
                $next->{value};
            if ( my $details = $next->{details} ) {
                unshift @stack, [@current];
                @current = @{$details};
                $indent += 2;
            }
        }
        $indent -= 2;
    }
    $hit->{_explanation} = \@text;
}

#===================================
sub _run_request {
#===================================
    my $indices = shift;
    my $request = shift;
    my $result  = eval {
        $es->search(
            index      => $indices,
            preference => '_local',
            body       => $request,

            # explain => 'true'
        );
    }
        || do { warn $@; return _as_json( 200, {} ) };

    my $last_page = int( $result->{hits}{total} / $Page_Size ) + 1;
    $last_page = $Max_Page if $last_page > $Max_Page;

    # _explain($result);

    # return _as_json( 200, $result );

    my %response = (
        total_hits   => $result->{hits}{total},
        current_page => ( $request->{from} / $Page_Size ) + 1,
        last_page    => $last_page,
        hits         => _format_hits($result),
        took         => $result->{took}
    );

    return _as_json( 200, \%response );
}

#===================================
sub _format_hits {
#===================================
    my $result = shift;
    return [ map { _format_hit($_) } @{ $result->{hits}{hits} } ];
}

#===================================
sub _format_hit {
#===================================
    my $hit = shift;

    # _explain( $hit->{inner_hits}{part} );
    my $inner    = $hit->{inner_hits}{part}{hits}{hits} || [];
    my $page_url = $hit->{_id};
    my %result   = (
        page_url    => $page_url,
        breadcrumbs => $hit->{_source}{breadcrumbs},
        $hit->{_source}{title} ? ( page_title => $hit->{_source}{title} ) : (),
        @$inner
        ? ( _format_inner_hit( $page_url, shift @$inner, 'highlight' ),
            _format_inner_hits( $page_url, $inner )
            )
        : ()
    );
    if ( my $highlights = $hit->{highlight}{"title.autocomplete"} ) {
        $result{title} ||= _format_highlights($highlights);
    }
    if ( my $highlights = $hit->{highlight}{"content.stemmed"} ) {
        $result{content} ||= _format_highlights($highlights);
    }

    return \%result;
}

#===================================
sub _format_inner_hits {
#===================================
    my ( $page_url, $hits ) = @_;
    my @results;
    for my $hit (@$hits) {
        next unless $hit->{_source}{part}{id};
        push @results, { _format_inner_hit( $page_url, $hit ) };
    }
    return unless @results;
    return ( other => \@results );
}

#===================================
sub _format_inner_hit {
#===================================
    my ( $page_url, $hit, $highlight ) = @_;
    my $id = $hit->{_source}{part}{id} || '';
    return (
        title => $hit->{_source}{part}{title},
        url   => $page_url . $id,

        #  _explanation => $hit->{_explanation},
        $highlight
        ? ( content =>
                _format_highlights( $hit->{highlight}{"part.content.stemmed"} )
            )
        : ()
    );
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
        if ( length $snippet > 300 ) {
            my $words = 10;
            while ( my $length = length $snippet > 300 ) {
                $snippet =~ s/(?:[.]{3})?(\w+\W+){$words,10}/.../;
                $words-- if $length == length $snippet;
            }
            $snippet =~ s/(?:[.]{3}\s*)+/... /g;
            $snippet =~ s/^\s*[.]{3}\s*//;
            $snippet =~ s/\s*[.]{3}\s*$//;
        }
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
        [   'Content-Type'                => 'application/json; charset=utf-8',
            'Access-Control-Allow-Origin' => '*'
        ],
        [ $JSON->encode($data) ]
    ];
}

#===================================
sub _as_text {
#===================================
    my ( $code, $text ) = @_;
    return [
        $code,
        [   'Content-Type'                => 'text/plain',
            'Access-Control-Allow-Origin' => '*'
        ],
        [$text]
    ];
}

