package ES::BranchTracker;

use strict;
use warnings;
use v5.10;

use Path::Class qw(dir);
use ES::Util qw(run sha_for);
use YAML qw(Dump Load);
use Storable qw(dclone);

my %Repos;

#===================================
sub new {
#===================================
    my ( $class, $file, @repos ) = @_;
    my %shas;

    if ( -e $file ) {
        my $yaml = $file->slurp( iomode => '<:utf8' );
        %shas = %{ Load($yaml) };
    }

    my $self = bless {
        file => $file,
        shas => \%shas,
    }, $class;

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
}

#===================================
sub prune_out_of_date {
#===================================
# Prunes tracker entries for books that are no longer built.
#===================================
    my ( $self, @entries ) = @_;
    my %allowed;
    _allowed_entries_from_books( \%allowed, @entries );

    while ( my ($repo, $branches) = each %{ $self->{shas} } ) {
        my $allowed_for_repo = $allowed{$repo} || '';
        unless ($allowed_for_repo) {
            say "Pruning for $repo";
            delete $self->{shas}->{$repo};
            next;
        }
        foreach my $branch ( keys %{ $branches } ) {
            # We can't clear the link check information at this point safely
            # because we need it for PR builds and we don't have a good way
            # tell if it'll be needed again. It is a problem, but not a big one
            # right now.
            unless ($allowed_for_repo->{$branch} || $branch =~ /^link-check/) {
                say "Pruning for $repo $branch";
                delete $branches->{$branch};
            }
        }
        # Empty can show up because there is a new book that weren't not
        # building at this time and we don't want that to force a commit so we
        # clean them up while we're purging here.
        delete $self->{shas}->{$repo} unless keys %{ $branches };
    }
}

#===================================
sub _allowed_entries_from_books {
#===================================
    my ( $allowed, @entries ) = @_;

    foreach my $book ( @entries ) {
        my $title = $book->{title};
        foreach ( @{ $book->{branches} } ) {
            my ( $branch, $branch_title ) = ref $_ eq 'HASH' ? (%$_) : ( $_, $_ );
            foreach my $source ( @{ $book->{sources} } ) {
                my $repo = $source->{repo};
                my $path = dir('.')->subdir( $source->{path} )->relative('.');
                my $mapped_branch = $source->{map_branches}{$branch} || $branch;
                $allowed->{$repo}{"$title/$path/$mapped_branch"} = 1;
            }
        }
        if (exists $book->{sections}) {
            _allowed_entries_from_books( $allowed, @{ $book->{sections} } );
        }
    }
}

#===================================
sub write {
#===================================
    my $self = shift;
    $self->file->parent->mkpath;
    $self->file->spew( iomode => '>:utf8', Dump( $self->{shas} ) );
}

#===================================
sub file { shift->{file} }
sub shas { shift->{shas} }
#===================================

1
