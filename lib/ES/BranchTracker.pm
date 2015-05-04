package ES::BranchTracker;

use strict;
use warnings;
use v5.10;

use Path::Class();
use ES::Util qw(run sha_for);
use YAML qw(Dump Load);

my %Repos;

#===================================
sub new {
#===================================
    my ( $class, $file ) = @_;
    my $shas = {};

    if ( -e $file ) {
        my $json = $file->slurp( iomode => '<:raw' );
        $shas = Load($json);
    }

    return bless {
        file => $file,
        shas => $shas
    };

}

#===================================
sub shas_for_repo {
#===================================
    my ( $self, $repo ) = @_;
    return $self->shas->{$repo} || {};
}

#===================================
sub sha_for_branch {
#===================================
    my ( $self, $repo, $branch ) = @_;
    return $self->shas->{$repo}{$branch} || '';
}

#===================================
sub set_sha_for_branch {
#===================================
    my ( $self, $repo, $branch, $sha ) = @_;
    $self->shas->{$repo}{$branch} = $sha;
    $self->write;
}

#===================================
sub delete_branch {
#===================================
    my ( $self, $repo, $branch ) = @_;
    my $shas = $self->shas;
    delete $shas->{$repo}{$branch} || return;
    unless ( keys %{ $shas->{$repo} } ) {
        delete $shas->{$repo};
    }
    $self->write;
}

#===================================
sub write {
#===================================
    my $self = shift;
    $self->file->spew( iomode => '>:raw', Dump( $self->shas ) );

}
#===================================
sub file { shift->{file} }
sub shas { shift->{shas} }
#===================================

1
