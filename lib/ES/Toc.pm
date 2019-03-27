package ES::Toc;

use strict;
use warnings;
use v5.10;
use ES::Util qw(build_single);

#===================================
sub new {
#===================================
    my ( $class, $title, $lang ) = @_;
    $lang ||= 'en';
    bless {
        title   => $title,
        lang    => $lang,
        entries => []
    }, $class;
}

#===================================
sub add_entry {
#===================================
    my $self = shift;
    push @{ $self->{entries} }, shift();
}

#===================================
sub write {
#===================================
    my ( $self, $dir, $indent ) = @_;
    $indent = 1 unless defined $indent;

    my $index = $dir->file('index.html');

    my $adoc = join "\n", "= " . $self->title, '', $self->render($indent);
    my $adoc_file = $dir->file('index.asciidoc');
    $adoc_file->spew( iomode => '>:utf8', $adoc );

    build_single( $adoc_file, $dir,
            type        => 'article',
            lang        => $self->lang,
            asciidoctor => 1,
            root_dir    => '',  # Required but thrown on the floor with asciidoctor
            latest      => 1,   # Run all of our warnings
            private     => 1,   # Don't generate edit me urls
    );
    $adoc_file->remove;
}

#===================================
sub render {
#===================================
    my ( $self, $indent ) = @_;
    my @adoc;

    my $prefix = $indent ? ' ' . ( '*' x $indent ) . ' ' : "[float]\n=== ";

    for my $entry ( $self->entries ) {
        if ( ref($entry) eq 'ES::Toc' ) {
            push @adoc, $prefix . $entry->{title};
            push @adoc, '' unless $indent;
            push @adoc, $entry->render( $indent + 1 );
            push @adoc, '' unless $indent;
        }
        else {
            push @adoc, $prefix . "link:$entry->{url}" . "[$entry->{title}]";
            if ( $entry->{versions} ) {
                $adoc[-1] .= " -- link:$entry->{versions}" . "[other versions]";
            }
            push @adoc, '' unless $indent;
        }
    }
    return @adoc;
}

#===================================
sub _toc {
#===================================
    my $indent = shift;
    my @adoc   = '';
    while ( my $entry = shift @_ ) {
        my $prefix = '  ' . ( '*' x $indent ) . ' ';

        if ( my $sections = $entry->{sections} ) {
            push @adoc, $prefix . $entry->{title};
            push @adoc, _toc( $indent + 1, @$sections );
        }
        else {
            my $versions
                = $entry->{versions}
                ? " link:$entry->{versions}" . "[(other versions)]"
                : '';
            push @adoc,
                  $prefix
                . "link:$entry->{url}"
                . "[$entry->{title}]"
                . $versions;
        }
    }
    return @adoc;
}

#===================================
sub title   { shift->{title} }
sub lang    { shift->{lang} }
sub entries { @{ shift->{entries} } }
#===================================
1;
