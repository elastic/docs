package ES::TargetRepo;

use strict;
use warnings;
use v5.10;

use Cwd;
use Path::Class();
use Encode qw(decode_utf8);
use ES::Util qw(run);

use parent qw( ES::BaseRepo );

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
    my $self = $class->SUPER::new(%args);

    $self->{destination} = $args{destination}
        or die "No <destination> specified for repo <target_repo>";
    $self->{branch} = $args{branch}
        or die "No <branch> specified for repo <target_repo>";

    $self;
}

#===================================
# Checks out the parts of this repo that are not built docs. This will make
# sure that we have the tracker file that we need to check out other repos.
#===================================
sub checkout_minimal {
#===================================
    my ( $self ) = @_;

    # Whether or not we'll need to force push the target branch.
    $self->{rebuilding_target_branch} = 0;

    my $original_pwd = Cwd::cwd();
    eval {
        my $out = run qw(git clone --no-checkout),
            $self->git_dir, $self->{destination};

        # This if statement handles empty repositories in a way that works with
        # different target branches. It always checks out the master
        # branch. If the target branch is `master` then it will return early.
        # If the target branch isn't master it'll delete the existing copy
        # of the branch.
        if ( $out =~ /You appear to have cloned an empty repository./) {
            $self->{started_empty} = 1;
            printf(" - %20s: Initializing empty master for empty repo\n",
                'target_repo');
            return 1 if $self->{branch} eq 'master';
            chdir $self->{destination};
            $self->{initialized_empty_master} = 1;
            run qw(git commit --allow-empty -m init);
        } else {
            $self->{started_empty} = 0;
            chdir $self->{destination};
            run qw(git config core.sparseCheckout true);
            $self->_write_sparse_config("/*\n!html/*/\n");
            run qw(git checkout master);
            return 1 if $self->{branch} eq 'master';
            if ( $self->_branch_exists( 'origin/' . $self->{branch} ) ) {
                $self->{rebuilding_target_branch} = 1;
            }
        }

        printf(" - %20s: Forking <%s> from master\n",
            'target_repo', $self->{branch});
        run qw(git checkout -b), $self->{branch};
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
# Returns truthy if there outstanding changes to the repo, falsy otherwise.
#===================================
sub outstanding_changes {
#===================================
    my ( $self ) = @_;
    local $ENV{GIT_WORK_TREE} = $self->{destination};
    local $ENV{GIT_DIR} = $ENV{GIT_WORK_TREE} . '/.git';

    # This command will list all modified files, including deleted files.
    # Unlike `git status` it won't group new directories.
    return run qw(git ls-files -zomd --);
}

#===================================
# Commits all changes to the repo.
#===================================
sub commit {
#===================================
    my ( $self ) = @_;
    local $ENV{GIT_WORK_TREE} = $self->{destination};
    local $ENV{GIT_DIR} = $ENV{GIT_WORK_TREE} . '/.git';

    run qw(git add -A);
    my $commit_msg = 'Updated docs';
    if ( $ENV{NODE_NAME} ) {
        $commit_msg .= "\n\nBuilt on $ENV{NODE_NAME}";
    }
    run qw(git commit -m), $commit_msg;
}

#===================================
# Push to the remote repo.
#===================================
sub push_changes {
#===================================
    my ( $self ) = @_;
    local $ENV{GIT_WORK_TREE} = $self->{destination};
    local $ENV{GIT_DIR} = $ENV{GIT_WORK_TREE} . '/.git';
    my @push_branch = qw(git push origin);
    push @push_branch, '--force' if $self->{rebuilding_target_branch};
    push @push_branch, $self->{branch};

    run qw(git push origin master) if $self->{initialized_empty_master};
    run @push_branch;
    local $ENV{GIT_DIR} = $self->{git_dir};
    run qw(git push origin master) if $self->{initialized_empty_master};
    run @push_branch;
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

#===================================
# Does a branch exist?
#===================================
sub _branch_exists {
#===================================
    my ( $self, $branch ) = @_;

    return eval { run qw(git rev-parse --verify), $branch };
}

#===================================
sub destination { shift->{destination} }
#===================================

1
