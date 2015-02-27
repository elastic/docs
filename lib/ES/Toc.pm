package ES::Toc;

use strict;
use warnings;
use v5.10;
use ES::Util qw(build_single);
use File::Copy::Recursive qw(fcopy);

#===================================
sub new {
#===================================
    my ( $class, $title ) = @_;
    bless {
        title   => $title,
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
    my ( $self, $dir ) = @_;

    my $index = $dir->file('index.html');

    my $adoc = join "\n", "= " . $self->title, '', $self->render(1);
    my $adoc_file = $dir->file('index.asciidoc');
    $adoc_file->spew( iomode => '>:utf8', $adoc );

    build_single( $adoc_file, $dir );
    fcopy( 'resources/styles.css', $dir )
        or die "Couldn't copy <styles.css> to <" . $dir . ">: $!";

    $adoc_file->remove;
}

#===================================
sub render {
#===================================
    my ( $self, $indent ) = @_;
    my @adoc;

    my $prefix = ' ' . ( '*' x $indent ) . ' ';

    for my $entry ( $self->entries ) {
        if ( ref($entry) eq 'ES::Toc' ) {
            push @adoc, $prefix . $entry->{title};
            push @adoc, $entry->render( $indent + 1 );
        }
        else {
            push @adoc, $prefix . "link:$entry->{url}" . "[$entry->{title}]";
            if ( $entry->{versions} ) {
                $adoc[-1]
                    .= " --  link:$entry->{versions}" . "[other versions]";
            }
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
sub entries { @{ shift->{entries} } }
#===================================
1;
