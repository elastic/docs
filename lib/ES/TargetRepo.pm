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
sub checkout_minimal {
#===================================
    my ( $self ) = @_;

    my $original_pwd = Cwd::cwd();
    eval {
        run qw(git clone --no-checkout), $self->git_dir, $self->{destination};
        chdir $self->{destination};
        run qw(git config core.sparseCheckout true);
        $self->_write_sparse_config("/*\n!html/*/\n");
        run qw(git checkout master);
        1;
    } or die "Error checking out repo <target_repo>: $@";
    chdir $original_pwd;
}

#===================================
sub checkout_all {
#===================================
    my ( $self ) = @_;

    my $original_pwd = Cwd::cwd();
    chdir $self->{destination};
    eval {
        $self->_write_sparse_config("*\n");
        run qw(git read-tree -mu HEAD);
        1;
    } or die "Error checking out repo <target_repo>: $@";
    chdir $original_pwd;
}

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
