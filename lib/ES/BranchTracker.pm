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
    my %allowed = $self->_allowed_entries_from_books( @entries );

    while (my ($repo, $branches) = each %{ $self->{shas} } ) {
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
                delete $self->{shas}->{$repo}->{$branch};
            }
        }
    }

    # Here is where you'd check if it worked
}

#===================================
sub _allowed_entries_from_books {
#===================================
    my ( $self, @entries ) = @_;
    my %allowed;

    foreach my $book ( @entries ) {
        my $title = $book->{title};
        foreach my $branch ( @{ $book->{branches} } ) {
            foreach my $source ( @{ $book->{sources} } ) {
                my $repo = $source->{repo};
                my $path = $source->{path};
                my $branch_mapping = $source->{map_branches} || ();
                my $mapped_branch = $source->{map_branches}{$branch} || $branch;
                $allowed{$repo}{"$title/$path/$mapped_branch"} = 1;
            }
        }
    }

    # NOCOMMIT recur with sections

    return %allowed;
}

#===================================
sub write {
#===================================
    my $self = shift;
    # TODO move the empty pruning into the pruning method above and just save here
    my $to_save = dclone( $self->shas );
    # Empty hashes are caused by new repos that are unused which shouldn't
    # force a commit.
    while (my ($repo, $branches) = each %{ $to_save } ) {
        unless ( keys %{ $branches } ) {
            delete $to_save->{$repo};
        }
    }
    $self->file->parent->mkpath;
    $self->file->spew( iomode => '>:utf8', Dump( $to_save ) );
}

#===================================
sub file { shift->{file} }
sub shas { shift->{shas} }
#===================================

1
