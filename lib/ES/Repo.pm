package ES::Repo;

use strict;
use warnings;
use v5.10;

use Path::Class();
use URI();
use Encode qw(decode_utf8);
use ES::Util qw(run sha_for);

my %Repos;

#===================================
sub new {
#===================================
    my ( $class, %args ) = @_;

    my $name = $args{name} or die "No <name> specified";
    my $url  = $args{url}  or die "No <url> specified for repo <$name>";
    if ( my $user = $args{user} ) {
        $url = URI->new($url);
        $url->userinfo($user);
    }

    my $dir = $args{dir} or die "No <dir> specified for repo <$name>";
    my $temp_dir = $args{temp_dir}
        or die "No <temp_dir> specified for repo <$name>";

    my $current = $args{current}
        or die "No <current> branch specified for repo <$name>";

    my $branches = $args{branches}
        or die "No <branches> specified for repo <$name>";

    die "<branches> must be an array in repo <$name>"
        unless ref $branches eq 'ARRAY';

    die "Current branch <$current> is not in <branches> in repo <$name>"
        unless grep { ref $_ ? $_->{$current} : $current eq $_ } @$branches;

    my $self = bless {
        name     => $name,
        git_dir  => $dir->subdir("$name.git"),
        temp_dir => $temp_dir,
        url      => $url,
        current  => $current,
        branches => $branches,
        private  => $args{private} || 0,
        tracker  => $args{tracker},
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

    my $git_dir = $self->git_dir;
    local $ENV{GIT_DIR} = $git_dir;

    my $name = $self->name;
    eval {
        unless ( $self->_try_to_fetch ) {
            my $url = $self->url;
            say " - Cloning $name from <$url>";
            run 'git', 'clone', '--bare', $url, $git_dir;
        }
        1;
    }
        or die "Error updating repo <$name>: $@";

}

#===================================
sub _try_to_fetch {
#===================================
    my $self    = shift;
    my $git_dir = $self->git_dir;
    return unless -e $git_dir;

    my $remote = eval { run qw(git remote -v) } || '';
    $remote =~ /^origin\s+(\S+)/;

    my $origin = $1;
    unless ($origin) {
        say " - Repo dir <$git_dir> exists but is not a repo. Deleting";
        $git_dir->rmtree;
        return;
    }

    my $name = $self->name;
    my $url  = $self->url;
    if ( $origin ne $url ) {
        say " - Updating remote for <$name> to: $url";
        run qw(git remote set-url origin), $url;
    }
    say " - Fetching: " . $self->name;
    run qw(git fetch --prune);
    return 1;
}

#===================================
sub local_clone {
#===================================
    my ( $self, $branch ) = @_;

    local $ENV{GIT_DIR} = $self->git_dir;
    my $sha = sha_for($branch);
    my $temp = Path::Class::tempdir( CLEANUP => 1, DIR => $self->temp_dir );
    run qw( git clone), $self->git_dir, $temp;

    local $ENV{GIT_DIR}       = $temp->subdir('.git');
    local $ENV{GIT_WORK_TREE} = $temp;

    run qw( git checkout --force -B), $branch, $sha;
    return $temp;

}

#===================================
sub has_changed {
#===================================
    my $self = shift;
    my ( $path, $branch ) = @_;

    my $old
        = $self->tracker->sha_for_branch( $self->name,
        $self->_tracker_branch(@_) )
        or return 1;

    local $ENV{GIT_DIR} = $self->git_dir;

    my $new = sha_for($branch)
        or die "Remote branch <origin/$branch> doesn't exist "
        . "in repo "
        . $self->name;

    return if $old eq $new;

    my $changed;
    eval {
        $changed = !!run qw(git diff --shortstat), $old, $new, '--', $path;
        1;
    }
        || do { $changed = 1 };
    return $changed;
}

#===================================
sub mark_done {
#===================================
    my $self = shift;
    my ( $path, $branch ) = @_;

    local $ENV{GIT_DIR} = $self->git_dir;

    my $new = sha_for($branch);
    $self->tracker->set_sha_for_branch( $self->name,
        $self->_tracker_branch(@_), $new );

}

#===================================
sub _tracker_branch {
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
sub dump_recent_commits {
#===================================
    my ( $self, $src_path, $branch ) = @_;
    local $ENV{GIT_DIR} = $self->git_dir;

    my $start = $self->tracker->sha_for( $self->name, $branch );
    my $rev_range = "$start...$branch";

    my $commits = eval {
        decode_utf8 run( 'git', 'log', $rev_range,
            '--pretty=format:%h -%d %s (%cr) <%an>',
            '-n', 10, '--abbrev-commit', '--date=relative', '--', $src_path );
    } || '';

    unless ( $commits =~ /\S/ ) {
        $commits
            = run( 'git', 'log',
            $branch, '--pretty=format:%h -%d %s (%cr) <%an>',
            '-n', 10, '--abbrev-commit', '--date=relative', '--', $src_path );
    }

    my $title = "Recent commits in " . $self->name . "/$branch - $src_path:";
    return $title . "\n" . ( '-' x length($title) ) . "\n" . $commits . "\n\n";
}

#===================================
sub all_repo_branches {
#===================================
    my $class = shift;
    my @out;
    for ( sort keys %Repos ) {
        my $repo = $Repos{$_};

        push @out, "Repo: " . $repo->name;
        push @out, '-' x 80;

        local $ENV{GIT_DIR} = $repo->git_dir;
        my $shas = $repo->tracker->shas_for_repo( $repo->name );

        for my $branch ( sort keys %$shas ) {
            my $log = run( qw(git log --oneline), $shas->{$branch} );
            my ($msg) = ( $log =~ /^\w+\s+([^\n]+)/ );
            push @out, sprintf "  %-35s %s   %s", $branch,
                substr( $shas->{$branch}, 0, 8 ), $msg;
        }
        push @out, '';

    }
    return join "\n", @out;
}

#===================================
sub name     { shift->{name} }
sub git_dir  { shift->{git_dir} }
sub temp_dir { shift->{temp_dir} }
sub url      { shift->{url} }
sub current  { shift->{current} }
sub branches { shift->{branches} }
sub private  { shift->{private} }
sub tracker  { shift->{tracker} }
#===================================

1
