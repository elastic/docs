package ES::DocsRepo;

use strict;
use warnings;
use v5.10;

use Path::Class();

use parent qw( ES::Repo );

#===================================
sub new {
#===================================
    my ( $class, $tracker, $dir ) = @_;

    $dir = Path::Class::dir( $dir );
    my $self = $class->SUPER::new(
        name      => 'docs',
        git_dir   => $dir->subdir( '.git' ),
        tracker   => $tracker,
        url       => 'git@github.com:elastic/docs.git',
        keep_hash => 0,
    );
    $self->{dir} = $dir;
    return $self;
}

#===================================
sub add_source {
#===================================
    my ( $self, $sources, $prefix, $path, $exclude, $map_branches, $private, $alternatives ) = @_;

    if ( $path eq 'shared/versions/stack/current.asciidoc' ) {
        push @$sources, {
            repo    => $self,
            prefix  => $prefix,
            path    => $self->_current_stack_version_file,
            exclude => $exclude,
            map_branches => $map_branches,
            private => $private,
            alternatives => $alternatives,
        };
    }

    $self->SUPER::add_source( $sources, $prefix, $path, $exclude, $map_branches, $private, $alternatives );
}

#===================================
# Use the files from the local filesystem.
#===================================
sub prepare {
#===================================
    my ( $self, $title, $branch, $path, $dest_root, $prefix ) = @_;

    return $self->{dir};
}

#===================================
# Lock the branch to the HEAD branch because that is what we've checked out.
#===================================
sub normalize_branch {
#===================================
    my ( $self, $branch ) = @_;
    return 'HEAD';
}

#===================================
# Add support for the special `{branch}` attribute to resolve paths that
# contain the branch of a book.
#===================================
sub normalize_path {
#===================================
    my ( $self, $path, $branch ) = @_;

    $path =~ s/\{branch\}/$branch/;

    return $path;
}

#===================================
sub _current_stack_version_file {
#===================================
    my ( $self ) = @_;
    unless ( $self->{current_stack_version_file} ) {
        my $current = $self->{dir}->file( 'shared/versions/stack/current.asciidoc' );
        my $contents = $current->slurp( iomode => '<:encoding(UTF-8)' );
        die "Can't parse current.asciidoc: $contents" unless $contents =~ /include::(.+)\[\]/;
        $self->{current_stack_version_file} = "shared/versions/stack/$1";
    }
    return $self->{current_stack_version_file};
}


1
