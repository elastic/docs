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

our ( $es, $Docs_Index, $Site_Index, $Max_Page, $Page_Size, $Max_Sections,
    $Max_Hits_Per_Section );

use FindBin;

BEGIN {
    chdir "$FindBin::RealBin/..";
    do "web/base.pl" or die $!;
}

#our $JSON = JSON::XS->new->utf8;
our $JSON = JSON::XS->new->utf8->pretty->canonical;

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

    _add_query(
        $request, $q,
        {   'title'   => 0,
            'content' => 3
        }
    );

    if ( my $section = _section_filter($q) ) {
        $request->{post_filter} = $section;
    }

    my %aggs = ();
    my $docs = $q->{docs};

    if ( $docs->{version} ) {
        $aggs{other_versions} = _sibling_sections($q);
        $aggs{other_books}    = _parent_sections($q);
    }
    elsif ( $docs->{book} ) {
        $aggs{other_books} = _sibling_sections($q);
    }
    elsif ( $docs->{product} ) {
        $aggs{books}          = _child_sections($q);
        $aggs{other_products} = _sibling_sections($q);
    }
    else {
        if ( $q->{section} ) {
            $aggs{other_sections} = _sibling_sections($q);
        }
        else {
            $aggs{sections} = _sibling_sections($q);
        }
        if ( $q->{section} =~ m{/$} ) {
            $aggs{products} = _child_sections($q);
        }
        $aggs{top_tags} = _top_tags($q);

    }
    $request->{aggs} = \%aggs;

    # return _as_json( 200, $request );
    return _run_request($request);
}

#===================================
sub suggest {
#===================================
    my $q = _parse_request(@_) or return _as_json( 200, {} );

    my $request = {
        from => 0,
        size => $Page_Size,
    };

    _add_query( $request, $q, { 'title' => 0 } );

    push @{ $request->{query}{bool}{filter} }, _section_filter($q);

    _add_top_hits( $request, $q );

    if ( $q->{section} !~ m{/$} ) {
        $request->{aggs}{top_tags} = _top_tags($q);
    }

    #   return _as_json(200,$request);
    return _run_request($request);
}

#===================================
sub _add_query {
#===================================
    my ( $request, $q, $fields ) = @_;

    my ( @filter, @must, @should );
    my @source = qw(section tags);

    push @filter, { term => { is_current => \1 } }
        unless $q->{docs}{version};

    push @filter, _tags_filter($q);

    if ( my $text = $q->{q} ) {
        push @must,
            {
            multi_match => {
                type                 => 'cross_fields',
                query                => $text,
                minimum_should_match => "0<100% 2<80%",
                fields               => [
                    'tags.autocomplete',
                    'section.autocomplete',
                    map {"$_.autocomplete"} keys %$fields
                ]
            },
            };
        push @should,
            {
            multi_match => {
                type   => 'cross_fields',
                query  => $text,
                fields => [ map { ( $_, "$_.shingles" ) } keys %$fields ]
            },
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
        $request->{highlight} = _highlight(%$fields);
    }
    else {
        push @filter, { exists => { field => 'published_at' } };
        push @source, keys %$fields;
        $request->{sort} = [
            {   "published_at" => {
                    order         => 'desc',
                    missing       => '_last',
                    unmapped_type => 'date'
                }
            }
        ];

    }

    $request->{query} = {
        bool => {
            must   => \@must,
            should => \@should,
            filter => \@filter
        }
    };
    $request->{_source} = \@source;

}

#===================================
sub _section_filter {
#===================================
    my $q = shift;
    my $section = $q->{section} or return;
    return { term => { section => $section } };
}

#===================================
sub _parent_section_filter {
#===================================
    my $q = shift;
    my $section = $q->{section} or return;
    $section =~ s{[^/]+/?$}{};
    return unless $section;
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
    my %fields    = @_;
    my %highlight = (
        pre_tags  => ['[[['],
        post_tags => [']]]'],
    );
    for ( keys %fields ) {
        $highlight{fields}{"$_.autocomplete"}{number_of_fragments}
            = $fields{$_};
    }
    return \%highlight;
}

#===================================
sub _add_top_hits {
#===================================
    my ( $request, $q ) = @_;

    my $section = $q->{section};
    my $include;
    if ( !$section ) {
        $include = '[^/]*/?';
    }
    elsif ( $section =~ m{/$} ) {
        if ( @{ $q->{tags} } ) {
            $include
                = $section . "(" . join( '|', @{ $q->{tags} } ) . ')/[^/]+/?';
        }
        else {
            $include = $section . '[^/]+/?';
        }
    }
    else {
        return;
    }

    $request->{size} = 0;
    $request->{aggs}{per_section} = {
        terms => {
            field   => 'section',
            size    => $Max_Sections,
            order   => { max_score => 'desc' },
            include => $include
        },
        aggs => {
            top_hits => {
                top_hits => {
                    sort      => delete $request->{sort},
                    _source   => delete $request->{_source},
                    highlight => delete $request->{highlight},
                    size      => $Max_Hits_Per_Section,
                }
            },
            max_score => {
                max =>
                    { script => { inline => '_score', lang => 'expression' } }
            }
        }
    };
}

#===================================
sub _top_tags {
#===================================
    my $q = shift;
    return {
        terms => {
            field   => 'tags',
            exclude => $q->{tags},
            size    => 100,
        },
    };
}

#===================================
sub _top_sections {
#===================================
    my $q       = shift;
    my $section = $q->{section};

    return {
        terms => {
            field   => 'section',
            exclude => [ $q->{section} ],
            size    => 100,
        },
    };
}

#===================================
sub _sibling_sections {
#===================================
    my $q      = shift;
    my $parent = $q->{section};
    $parent =~ s{[^/]+/?$}{};
    return _section_agg( $parent, $q->{section} );
}

#===================================
sub _parent_sections {
#===================================
    my $q      = shift;
    my $parent = $q->{section};
    $parent =~ s{[^/]+/?$}{};
    my $grand_parent = $parent;
    $grand_parent =~ s{[^/]+//?$}{};
    return _section_agg( $grand_parent, $parent );
}
#===================================
sub _child_sections {
#===================================
    my $q       = shift;
    my $section = $q->{section};
    return _section_agg( $section, $section );
}

#===================================
sub _section_agg {
#===================================
    my ( $include, $exclude ) = @_;
    return {
        terms => {
            field   => 'section',
            include => $include . '[^/]+/?',
            exclude => $exclude,
            size    => 100,
        },
    };
}

#===================================
sub _run_request {
#===================================
    my $request = shift;
    my $result  = eval {
        $es->search(
            index         => _indices(),
            request_cache => 'true',
            preference    => '_local',
            body          => $request
        );
    }
        || do { warn $@; return _as_json( 200, {} ) };

    my $last_page = int( $result->{hits}{total} / $Page_Size ) + 1;
    $last_page = $Max_Page if $last_page > $Max_Page;

    my %response = (
        total_hits   => $result->{hits}{total},
        current_page => ( $request->{from} / $Page_Size ) + 1,
        last_page    => $last_page,
        hits         => _format_hits($result),
        aggs         => _format_aggs($result)
    );

    #return _as_json( 200, $result );
    return _as_json( 200, \%response );
}

#===================================
sub _indices {
#===================================
    return [ $Docs_Index, $Site_Index ];
}

#===================================
sub _format_hits {
#===================================
    my $result = shift;
    my @hits;
    if ( my $sections = delete $result->{aggregations}{per_section} ) {
        for my $section ( @{ $sections->{buckets} } ) {
            for my $hit ( @{ $section->{top_hits}{hits}{hits} } ) {
                $hit = _format_hit($hit);
                $hit->{section} = $section->{key};
                push @hits, $hit;
            }
        }

        # add back as "sections" agg for doc counts
        $result->{aggregations}{sections} ||= $sections;
    }
    else {
        push @hits, map { _format_hit($_) } @{ $result->{hits}{hits} };
    }
    return \@hits;
}

#===================================
sub _format_hit {
#===================================
    my $hit    = shift;
    my %result = (
        url     => $hit->{_id},
        section => $hit->{_source}{section},
        tags    => $hit->{_source}{tags}
    );

    for my $field (qw(title content)) {
        my $highlight
            = _format_highlights( $hit->{highlight}{"$field.autocomplete"} )
            || $hit->{_source}{$field}
            || next;
        $result{$field} = $highlight;
    }
    return \%result;
}

#===================================
sub _format_aggs {
#===================================
    my $result = shift;
    my %aggs;

    for my $agg ( keys %{ $result->{aggregations} } ) {
        my @buckets;
        for ( @{ $result->{aggregations}{$agg}{buckets} } ) {
            push @buckets, { $_->{key} => $_->{doc_count} };
        }
        $aggs{$agg} = \@buckets;

    }
    return \%aggs;
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

