package ES::DocsParser;

use strict;
use warnings;
use parent 'HTML::Parser';

#===================================
sub new {
#===================================
    shift()->SUPER::new(
        api_version     => 3,
        ignore_elements => [ 'script', 'style', 'head', 'pre' ],
        report_tags     => [
            "a",  "article", "aside",      "blockquote",
            "br", "caption", "dd",         "div",
            "dl", "dt",      "figcaption", "h1",
            "h2", "h3",      "h4",         "h5",
            "h6", "header",  "li",         "output",
            "p",  "pre",     "section",    "textarea",
            "th"
        ],
        handlers => {
            text    => [ \&text,    'self, dtext' ],
            start   => [ \&start,   'self, tagname, attr' ],
            end     => [ \&end,     'self, tagname' ],
            comment => [ \&comment, 'self, token0' ],
            default => ['']
        },
        empty_element_tags => 1,
    );
}

#===================================
sub comment {
#===================================
    my ( $self, $comment ) = @_;
    if ( $comment eq ' start body ' ) {
        $self->new_stack('text');
        $self->{sections} = [];
    }
    elsif ( $comment eq ' end body ' ) {
        $self->eof;
    }

}

#===================================
sub text {
#===================================
    my ( $self, $text ) = @_;
    return unless $self->{stack};

    my $dest = $self->{stack}[-1][0];
    return if $dest eq 'ignore';
    return unless $text =~ /\S/;

    $text =~ s/\s+/ /g;
    $text =~ s/^ //;
    $text =~ s/ $//;
    $text =~ s/\x{2019}/'/g;

    if ( $dest eq 'breadcrumbs' ) {
        push @{ $self->{breadcrumbs} }, $text;
    }
    return unless @{ $self->{sections} };
    push @{ $self->{sections}[-1]{$dest} }, $text;
}

#===================================
sub start {
#===================================
    my ( $self, $tag, $attr ) = @_;
    return unless $self->{stack};

    my $current = $self->{stack}[-1];

    # ignoring section
    if ( $current->[0] eq 'ignore' ) {
        push @{ $current->[1] }, $tag;
        return;
    }

    my $class = $attr->{class} || '';
    if ( $current->[0] eq 'title' ) {
        if ( $tag eq 'a' ) {
            $self->{sections}[-1]{id} = $attr->{id} if $attr->{id};
            $self->new_stack( 'ignore', $tag ) if $class eq 'edit_me';
        }
        return;
    }

    if ( $tag eq 'div' ) {
        return $self->new_stack('breadcrumbs')
            if $class eq 'breadcrumbs';

        return $self->new_stack( 'ignore', $tag )
            if $class =~ 'navheader'
            || $class eq 'navfooter'
            || $class eq 'toc';
    }

    return $self->new_stack( 'ignore', $tag )
        if $tag eq 'a' and $class =~ /(console|sense)_widget/;

    if ( $tag =~ /^h\d/ ) {
        $self->new_stack('title');
        $self->new_section;
    }

}

#===================================
sub new_stack { push @{ shift()->{stack} }, [ shift(), [@_] ] }
sub new_section { push @{ shift()->{sections} }, { title => [], text => [] } }
#===================================

#===================================
sub end {
#===================================
    my ( $self, $tag ) = @_;
    return unless $self->{stack};
    my $current = $self->{stack}[-1];

    if ( $current->[0] eq 'breadcrumbs' ) {
        pop @{ $self->{stack} } if $tag eq 'div';
        return;
    }

    if ( $current->[0] eq 'title' ) {
        pop @{ $self->{stack} } if $tag =~ /^h\d/;
        return;
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

    my $breadcrumbs = join " ", @{ $self->{breadcrumbs} || [] };
    my @sections;
    for my $section ( @{ $self->{sections} } ) {
        my $title = join( " ", @{ $section->{title} } );
        my $text  = join( " ", @{ $section->{text} } );
        if ( $section->{id} && $section->{text} ) {
            push @sections,
                {
                title => $title,
                text  => $text,
                id    => "#" . $section->{id}
                };
        }
        else {
            $sections[-1]{text} .= "\n\n$title\n\n$text";
        }
    }
    $sections[0]{id} = '';
    return { sections => \@sections, breadcrumbs => $breadcrumbs };
}

1;
