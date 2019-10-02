package ES::BranchTracker;

use strict;
use warnings;
use v5.10;

use ES::Repo();
use Path::Class qw(dir);
use YAML qw(Dump Load);

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
        has_non_local_changes => 0,
        allowed => {},
    }, $class;

    return $self;
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

    return if defined $self->shas->{$repo}{$branch} && $self->shas->{$repo}{$branch} eq $sha;
    $self->{has_non_local_changes} = 1 unless $sha =~ /^local/;
    $self->shas->{$repo}{$branch} = $sha;
}

#===================================
# Mark a book to keep to it isn't pruned before saving.
#===================================
sub allowed_book {
#===================================
    my ( $self, $book ) = @_;

    my $title = $book->{title};
    for my $branch ( @{ $book->{branches} } ) {
        for my $source ( @{ $book->source->sources } ) {
            my $repo = $source->{repo};
            my $path = $repo->normalize_path( $source->{path}, $branch );
            my $mapped_branch = $source->{map_branches}{$branch} || $branch;
            $self->{allowed}->{$repo->name}{"$title/$path/$mapped_branch"} = 1;
        }
    }
}

#===================================
# Prunes tracker entries for books that are no longer built.
#===================================
sub prune_out_of_date {
#===================================
    my ( $self ) = @_;

    while ( my ($repo, $branches) = each %{ $self->{shas} } ) {
        my $allowed_for_repo = $self->{allowed}{$repo} || '';
        unless ($allowed_for_repo) {
            delete $self->{shas}->{$repo};
            next;
        }
        foreach my $branch ( keys %{ $branches } ) {
            # We can't clear the link check information at this point safely
            # because we need it for PR builds and we don't have a good way
            # tell if it'll be needed again. It is a problem, but not a big one
            # right now.
            unless ($allowed_for_repo->{$branch} || $branch =~ /^link-check/) {
                delete $branches->{$branch};
                $self->{has_non_local_changes} = 1;
            }
        }
        # Empty can show up because there is a new book that were not
        # building at this time and we don't want that to force a commit so we
        # clean them up while we're purging here.
        delete $self->{shas}->{$repo} unless keys %{ $branches };
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
sub has_non_local_changes {
#===================================
# Truthy if any book was rebuilt with non-local changes.
#===================================
    shift->{has_non_local_changes};
}

#===================================
sub file { shift->{file} }
sub shas { shift->{shas} }
#===================================

1
