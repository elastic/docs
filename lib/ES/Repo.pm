package ES::Repo;

use strict;
use warnings;
use v5.10;

use Path::Class();
use ES::Util qw(run sha_for);

my %Repos;

#===================================
sub new {
#===================================
    my ( $class, %args ) = @_;

    my $name = $args{name} or die "No <name> specified";
    my $dir  = $args{dir}  or die "No <dir> specified for repo <$name>";
    my $url  = $args{url}  or die "No <url> specified for repo <$name>";

    my $current = $args{current}
        or die "No <current> branch specified for repo <$name>";

    my $branches = $args{branches}
        or die "No <branches> specified for repo <$name>";

    die "<branches> must be an array in repo <$name>"
        unless ref $branches eq 'ARRAY';

    die "Current branch <$current> is not in <branches> in repo <$name>"
        unless grep { $current eq $_ } @$branches;

    my $self = bless {
        name     => $name,
        dir      => $dir->subdir($name),
        git_dir  => $dir->subdir( $name, '.git' ),
        url      => $url,
        current  => $current,
        branches => $branches,
        private  => $args{private} || 0
    }, $class;
    $Repos{$name} = $self;
}

#===================================
sub get_repo {
#===================================
    my $class = shift;
    my $name = shift || '';
    return $Repos{$name} || die "Unknown repo name <$name>";
}

#===================================
sub update_from_remote {
#===================================
    my $self = shift;
    my $dir  = $self->dir;

    local $ENV{GIT_DIR} = $self->git_dir;

    my $name = $self->name;
    eval {
        unless ( $self->_try_to_fetch ) {
            my $url = $self->url;
            say " - Cloning $name from <$url>";
            run 'git', 'clone', $url, $dir;
        }
        1;
    }
        or die "Error updating repo <$name>: $@";
}

#===================================
sub _try_to_fetch {
#===================================
    my $self = shift;
    my $dir  = $self->dir;
    return unless -e $dir;

    my $remote = eval { run qw(git remote -v) } || '';
    $remote =~ /^origin\s+(\S+)/;

    unless ($1) {
        say " - Repo dir <$dir> exists but is not a repo. Deleting";
        $dir->rmtree;
        return;
    }

    my $name = $self->name;
    my $url  = $self->url;
    if ( $1 ne $url ) {
        say " - Updating remote for <$name> to: $url";
        run qw(git remote set-url origin), $url;
    }
    say " - Fetching: " . $self->name;
    run qw(git fetch);
    return 1;
}

#===================================
sub checkout {
#===================================
    my $self = shift;
    my ( $path, $branch ) = @_;

    my $tracker = $self->tracker_branch(@_);

    local $ENV{GIT_DIR}       = $self->git_dir;
    local $ENV{GIT_WORK_TREE} = $self->dir;

    run qw( git reset --hard );
    run qw( git clean --force -d);
    run qw( git checkout -B _build_docs ), "origin/$branch";
    return 1;
}

#===================================
sub has_changed {
#===================================
    my $self = shift;
    my ( $path, $branch ) = @_;

    my $tracker = $self->tracker_branch(@_);

    local $ENV{GIT_DIR} = $self->git_dir;

    my $new = sha_for("refs/remotes/origin/$branch")
        or die "Remote branch <origin/$branch> doesn't exist "
        . "in repo "
        . $self->name;

    my $old = sha_for("refs/heads/$tracker")
        or return 1;

    return if $old eq $new;

    return !!run qw(git diff --shortstat), $old, $new, '--', $path;
}

#===================================
sub mark_done {
#===================================
    my $self = shift;
    my ( $path, $branch ) = @_;

    my $tracker = $self->tracker_branch(@_);

    local $ENV{GIT_DIR}       = $self->git_dir;
    local $ENV{GIT_WORK_TREE} = $self->dir;

    run qw( git checkout -B), $tracker, "refs/remotes/origin/$branch";
    run qw( git branch -D _build_docs);
}

#===================================
sub tracker_branch {
#===================================
    my $self   = shift;
    my $path   = shift or die "No <path> specified";
    my $branch = shift or die "No <branch> specified";
    return "_${path}_${branch}";
}

#===================================
sub edit_url {
#===================================
    my ( $self, $branch, $index ) = @_;
    return '' if $self->private;
    my $url = $self->url;
    $url =~ s/\.git$//;
    my $dir = Path::Class::dir( "edit", $branch, $index->dir )
        ->cleanup->as_foreign('Unix');
    return "$url/$dir";
}

#===================================
sub name     { shift->{name} }
sub dir      { shift->{dir} }
sub git_dir  { shift->{git_dir} }
sub url      { shift->{url} }
sub current  { shift->{current} }
sub branches { shift->{branches} }
sub private  { shift->{private} }
#===================================

1
