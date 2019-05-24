package ES::BranchTracker;

use strict;
use warnings;
use v5.10;

use Path::Class();
use ES::Util qw(run sha_for);
use YAML qw(Dump Load);
use Storable qw(dclone);

my %Repos;

#===================================
sub new {
#===================================
    my ( $class, $file, @repos ) = @_;
    my $old  = {};
    my $yaml = '';

    if ( -e $file ) {
        my $yaml = $file->slurp( iomode => '<:utf8' );
        $old = Load($yaml);
    }

    my %new;
    for (@repos) {
        $new{$_} = $old->{$_} || {};
    }

    my $self = bless {
        file => $file,
        shas => \%new,
        yaml => $yaml,
    }, $class;
    $self->write;
    return $self;

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
    my $to_save = dclone( $self->shas );
    # Empty hashes are caused by new repos that are unused which shouldn't
    # force a commit.
    while (my ($repo, $branches) = each %{ $to_save } ) {
        unless ( keys %{ $branches } ) {
            delete $to_save->{$repo};
        }
    }
    my $new  = Dump( $to_save );
    return if $new eq $self->{yaml};
    $self->file->parent->mkpath;
    $self->file->spew( iomode => '>:utf8', $new );
    $self->{yaml} = $new;
}

#===================================
sub file { shift->{file} }
sub shas { shift->{shas} }
#===================================

1
