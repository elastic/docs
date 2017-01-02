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
        report_tags     => [ "div", "meta", "title", "span", "a" ],
        handlers        => {
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
}

#===================================
sub text {
#===================================
    my ( $self, $text ) = @_;
    return unless @{ $self->{stack} };

    my $dest = $self->{stack}[-1][0];
    return if $dest eq 'ignore';
    return unless $text =~ /\S/;

    $text =~ s/\s+/ /g;
    $text =~ s/^ //;
    $text =~ s/ $//;
    $text =~ s/\x{2019}/'/g;

    push @{ $self->{$dest} }, $text;
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
        return;
    }

    if ( $tag eq 'title' ) {
        return $self->new_stack( 'title', $tag );
    }

    my $id    = $attr->{id}    || '';
    my $class = $attr->{class} || '';

    return $self->new_stack( 'ignore', $tag )
        if $tag eq 'span' && $class eq "blog-date"
        || $tag eq 'a' && $class eq 'label-releases';

    if ( $tag eq 'div' ) {
        if ( $class eq 'main-container' ) {
            return $self->new_stack('content');
        }
        $self->eof
            if $id eq 'footer-subscribe'
            || $id eq 'parsely-root'
            || $class eq 'blog-sidebar-section';
    }

}

#===================================
sub new_stack { push @{ shift()->{stack} }, [ shift(), [@_] ] }
#===================================

#===================================
sub end {
#===================================
    my ( $self, $tag ) = @_;
    my $current = $self->{stack}[-1] || return;

    if ( $current->[0] eq 'title' ) {
        return pop @{ $self->{stack} } if $tag eq 'title';
    }

    return unless $current->[0] eq 'ignore';
    while ( my $old = pop @{ $current->[-1] } ) {
        last if $old eq $tag;
    }
    if ( @{ $current->[-1] } == 0 ) {
        pop @{ $self->{stack} };
    }
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
