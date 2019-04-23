package ES::TargetRepo;

use strict;
use warnings;
use v5.10;

use Cwd;
use Path::Class();
use Encode qw(decode_utf8);
use ES::Util qw(run sha_for);

use base qw( ES::BaseRepo );

my %Repos;

#===================================
# Create a repo for tracking *built* docs. This creation doesn't do anything
# on disk and the repo should be prepared by calling `update_from_remote` and
# `checkout_minimal`. The first call interacts with the network and can take
# a long time, especially if the repo doesn't exist locally. The second call
# is generally much quicker.
#===================================
sub new {
#===================================
    my ( $class, %args ) = @_;

    $args{name} = 'target_repo';
    my $self = shift->SUPER::new(%args);

    $self->{destination} = $args{destination}
        or die die "No <destination> specified for repo <target_repo>";

    $self;
}

#===================================
# Checks out the parts of this repo that are not built docs. This will make
# sure that we have the tracker file that we need to check out other repos.
#===================================
sub checkout_minimal {
#===================================
    my ( $self ) = @_;

    my $original_pwd = Cwd::cwd();
    eval {
        my $out = run qw(git clone --no-checkout),
            $self->git_dir, $self->{destination};
        if ( $out =~ /You appear to have cloned an empty repository./) {
            $self->{started_empty} = 1;
        } else {
            $self->{started_empty} = 0;
            chdir $self->{destination};
            run qw(git config core.sparseCheckout true);
            $self->_write_sparse_config("/*\n!html/*/\n");
            run qw(git checkout master);
        }
        1;
    } or die "Error checking out repo <target_repo>: $@";
    chdir $original_pwd;
}

#===================================
# Checks out the rest of the repo. This must be finished before we can build
# docs into the repo.
#===================================
sub checkout_all {
#===================================
    my ( $self ) = @_;

    my $original_pwd = Cwd::cwd();
    chdir $self->{destination};
    eval {
        $self->_write_sparse_config("*\n");
        run qw(git read-tree -mu HEAD) unless $self->{started_empty};
        1;
    } or die "Error checking out repo <target_repo>: $@";
    chdir $original_pwd;
}

#===================================
# Write a sparse checkout config for the repo.
#===================================
sub _write_sparse_config {
#===================================
    my ( $self, $config ) = @_;

    open(my $sparse, '>',
        $self->{destination}
             ->subdir( '.git' )
             ->subdir( 'info' )
             ->file( 'sparse-checkout' ))
        or dir("Couldn't write sparse config");
    print $sparse $config;
    close $sparse;
}

1
