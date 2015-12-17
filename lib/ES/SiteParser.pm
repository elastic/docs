package ES::SiteParser;

use strict;
use warnings;
use parent 'HTML::Parser';

#===================================
sub new {
#===================================
    shift()->SUPER::new(
        api_version     => 3,
        ignore_elements => [ 'script', 'style' ],
        report_tags     => [
            "article", "aside",      "blockquote", "br",
            "caption", "dd",         "div",        "dl",
            "dt",      "figcaption", "h1",         "h2",
            "h3",      "h4",         "h5",         "h6",
            "header",  "li",         "meta",       "output",
            "p",       "pre",        "section",    "textarea",
            "th",      "title"
        ],
        handlers => {
            text           => [ \&text,      'self, dtext' ],
            start          => [ \&start,     'self, tagname, attr' ],
            end            => [ \&end,       'self, tagname' ],
            start_document => [ \&start_doc, 'self' ],
            default        => ['']
        },
        empty_element_tags => 1,
    );
}

#===================================
sub start_doc {
#===================================
    my $self = shift;
    $self->{title}   = [];
    $self->{content} = [];
    $self->{stack}   = [];
    $self->{tags}    = [];
    $self->{section} = '';
    $self->{dest}    = 'ignore';
}

#===================================
sub text {
#===================================
    my ( $self, $text ) = @_;
    return if $self->{dest} eq 'ignore';
    return unless $text =~ /\S/;
    $text =~ s/\s+/ /g;
    $text =~ s/^ //;
    $text =~ s/ $//;
    $text =~ s/\x{2019}/'/g;
    push @{ $self->{ $self->{dest} } }, $text;

}

#===================================
sub start {
#===================================
    my ( $self, $tag, $attr ) = @_;

    if ( $tag eq 'meta' ) {
        my $name    = $attr->{name}    || '';
        my $content = $attr->{content} || '';

        if ($content) {
            if ( $name eq 'DC.title' ) {
                $self->{title} = [$content];
            }
            elsif ( $name eq 'DC.type' ) {
                $self->{section} = $content;
            }
            elsif ( $name eq 'DC.subject' ) {
                push @{ $self->{tags} }, split /\s*,\s*/, $content;
            }
            elsif ( $name eq 'date' ) {
                $self->{published_at} = $content || undef;
            }
        }
        $self->{dest} = 'ignore';
    }

    if ( $tag eq 'title' ) {
        return $self->{dest} = @{ $self->{title} } ? 'ignore' : 'title';
    }
    if ( $tag eq 'div' ) {
        my $id = $attr->{id} || '';
        return $self->{dest} = 'content'
            if $self->{dest} eq 'ignore' and $id eq 'content';
        $self->{dest} = 'ignore' if $id eq 'footer-wrapper';
    }
    return if $self->{dest} eq 'ignore';
    push @{ $self->{stack} }, $tag;

}

#===================================
sub end {
#===================================
    my ( $self, $tag ) = @_;
    return if $self->{dest} eq 'ignore';
    return $self->{dest} = 'ignore'
        if $tag eq 'title';
    my $stack = $self->{stack};
    while ( my $old = pop @$stack ) {
        last if $old eq $tag;
    }
    my $dest = $self->{ $self->{dest} };
    push @$dest, "\n" if @$dest and $dest->[-1] ne "\n";
}

#===================================
sub output {
#===================================
    my $self = shift;
    return {
        title        => join( " ", @{ $self->{title} } ),
        content      => join( " ", @{ $self->{content} } ),
        section      => $self->{section},
        tags         => $self->{tags},
        published_at => $self->{published_at}
    };
}

1;
