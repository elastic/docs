package ES::BaseRepo;

use strict;
use warnings;
use v5.10;

use Path::Class();
use URI();
use ES::Util qw(run);

#===================================
sub new {
#===================================
    my ( $class, %args ) = @_;

    my $name = $args{name} or die "No <name> specified";
    my $url  = $args{url}  or die "No <url> specified for repo <$name>";
    # TODO drop user because we no longer use it.
    if ( my $user = $args{user} ) {
        $url = URI->new($url);
        $url->userinfo($user);
    }

    my $reference_dir = 0;
    if ($args{reference}) {
        my $reference_subdir = $url;
        $reference_subdir =~ s|/$||;
        $reference_subdir =~ s|:*/*\.git$||;
        $reference_subdir =~ s/.*[\/:]//g;
        $reference_dir = $args{reference}->subdir("$reference_subdir.git");
    }

    return bless {
        name          => $name,
        git_dir       => $args{git_dir},
        url           => $url,
        reference_dir => $reference_dir,
        sub_dirs      => {},
    }, $class;
}

#===================================
sub update_from_remote {
#===================================
    my $self = shift;
    my $git_dir = $self->git_dir;
    local $ENV{GIT_DIR} = $git_dir;

    my $name = $self->name;
    eval {
        unless ( $self->_try_to_fetch ) {
            my $url = $self->url;
            printf(" - %20s: Cloning from <%s>\n", $name, $url);
            run 'git', 'clone', '--bare', $self->_reference_args, $url, $git_dir;
        }
        1;
    }
    or die "Error updating repo <$name>: $@";
}

#===================================
sub sha_for_branch {
#===================================
    my ( $self, $branch ) = @_;

    local $ENV{GIT_DIR} = $self->git_dir;
    $branch = $self->normalize_branch( $branch );
    my $sha = eval { run 'git', 'rev-parse', $branch } || ''; # NOCOMMIT check if eval is still useful
    chomp $sha; # NOCOMMIT check if we still need to chomp
    return $sha;
}

#===================================
sub fetch {
#===================================
    my $self = shift;
    local $ENV{GIT_DIR} = $self->git_dir;

    return run qw(git fetch --prune origin +refs/heads/*:refs/heads/*);
}

#===================================
sub normalize_path {
#===================================
    my ( $self, $path, $branch ) = @_;

    return $path;
}

#===================================
sub normalize_branch {
#===================================
    my ( $self, $branch ) = @_;

    return $branch;
}

#===================================
sub _try_to_fetch {
#===================================
    my $self    = shift;
    my $git_dir = $self->git_dir;
    return unless -e $git_dir;

    my $alternates_file = $git_dir->file('objects', 'info', 'alternates');
    if ( -e $alternates_file ) {
        my $alternates = $alternates_file->slurp( iomode => '<:encoding(UTF-8)' );
        chomp( $alternates );
        unless ( -e $alternates ) {
            printf(" - %20s: Missing reference. Deleting\n", $self->name);
            $git_dir->rmtree;
            return;
        }
    }

    my $remote = eval { run qw(git remote -v) } || '';
    $remote =~ /^origin\s+(\S+)/;

    my $origin = $1;
    unless ($origin) {
        printf(" - %20s: Repo dir exists but is not a repo. Deleting\n", $self->name);
        $git_dir->rmtree;
        return;
    }

    my $name = $self->name;
    my $url  = $self->url;
    if ( $origin ne $url ) {
        printf(" - %20s: Upstream has changed from <%s> to <%s>. Deleting\n",
                $self->name, $origin, $url);
        $git_dir->rmtree;
        return;
    }
    printf(" - %20s: Fetching\n", $self->name);
    $self->fetch();
    return 1;
}

#===================================
sub _reference_args {
#===================================
    my $self = shift;
    return () unless $self->{reference_dir};
    return ('--reference', $self->{reference_dir}) if -e $self->{reference_dir};
    say " - Reference missing so not caching: " . $self->{reference_dir};
    $self->{reference_dir} = 0;  # NOCOMMIT check me
    return ();
}

#===================================
sub name          { shift->{name} }
sub git_dir       { shift->{git_dir} }
sub url           { shift->{url} }
#===================================

1
