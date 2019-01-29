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

    my $reference_dir = 0;
    if ($args{reference}) {
        my $reference_subdir = $url;
        $reference_subdir =~ s|/$||;
        $reference_subdir =~ s|:*/*\.git$||;
        $reference_subdir =~ s/.*[\/:]//g;
        $reference_dir = $args{reference}->subdir("$reference_subdir.git");
    }

    my $self = bless {
        name          => $name,
        git_dir       => $dir->subdir("$name.git"),
        url           => $url,
        tracker       => $args{tracker},
        reference_dir => $reference_dir,
    }, $class;
    if ( $self->tracker ) {
        # Only track repos that have a tracker. Other repos are for things like
        # the target_branch.
        $Repos{$name} = $self;
    }
    $self;
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
            run 'git', 'clone', '--bare', $self->_reference_args, $url, $git_dir;
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
        say " - Upstream has changed to <$url>. Deleting";
        $git_dir->rmtree;
        return;
    }
    say " - Fetching: " . $self->name;
    run qw(git fetch --prune origin +refs/heads/*:refs/heads/*);
    return 1;
}

#===================================
sub _reference_args {
#===================================
    my $self = shift;
    return () unless $self->reference_dir;
    return ('--reference', $self->reference_dir) if -e $self->reference_dir;
    say " - Reference missing so not caching: " . $self->reference_dir;
    $self->{reference_dir} = 0;
    return ();
}

#===================================
sub has_changed {
#===================================
    my $self = shift;
    my ( $title, $branch, $path ) = @_;

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
    my ( $title, $branch, $path ) = @_;

    local $ENV{GIT_DIR} = $self->git_dir;

    my $new = sha_for($branch);
    $self->tracker->set_sha_for_branch( $self->name,
        $self->_tracker_branch(@_), $new );

}

#===================================
sub tree {
#===================================
    my $self = shift;
    my ( $branch, $path ) = @_;

    local $ENV{GIT_DIR} = $self->git_dir;

    my @files;
    eval {
        @files = map { Path::Class::file($_) } split /\0/,
            run( qw(git ls-tree -r --name-only -z), $branch, '--', $path );
        1;
    } or do {
        my $error = $@;
        die "Unknown branch <$branch> in repo <" . $self->name . ">"
            if $error =~ /Not a valid object name/;
        die $@;
    };
    return @files;
}

#===================================
sub extract {
#===================================
    my $self = shift;
    my ( $branch, $path, $dest ) = @_;
    local $ENV{GIT_DIR} = $self->git_dir;

    $dest->mkpath;
    my $tar = $dest->file('.temp_git_archive.tar');
    die "File <$tar> already exists" if -e $tar;
    run qw(git archive --format=tar -o ), $tar, $branch, $path;

    run "tar", "-x", "-C", $dest, "-f", $tar;
    $tar->remove;
}

#===================================
sub show_file {
#===================================
    my $self = shift;
    my ( $branch, $file ) = @_;

    local $ENV{GIT_DIR} = $self->git_dir;

    return decode_utf8 run( qw (git show ), $branch . ':' . $file );
}

#===================================
sub _tracker_branch {
#===================================
    my $self   = shift;
    my $title  = shift or die "No <title> specified";
    my $branch = shift or die "No <branch> specified";
    my $path   = shift or die "No <path> specified";
    return "$title/${path}/${branch}";
}

#===================================
sub edit_url {
#===================================
    my ( $self, $branch ) = @_;
    return edit_url_for_url_and_branch($self->url, $branch);
}

#===================================
sub edit_url_for_url_and_branch {
#===================================
    my ( $url, $branch ) = @_;
    # If the url is in ssh form, then convert it to https
    $url =~ s/git@([^:]+):/https:\/\/$1\//;
    # Strip trailing .git as it isn't in the edit link
    $url =~ s/\.git$//;
    my $dir = Path::Class::dir( "edit", $branch )->cleanup->as_foreign('Unix');
    return "$url/$dir/";
}

#===================================
sub dump_recent_commits {
#===================================
    my ( $self, $title, $branch, $src_path ) = @_;
    local $ENV{GIT_DIR} = $self->git_dir;

    my $start = $self->tracker->sha_for_branch( $self->name,
        $self->_tracker_branch( $title, $branch, $src_path ) );
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

    my $header
        = "Recent commits in " . $self->name . "/$title:$branch:$src_path:";
    return
          $header . "\n"
        . ( '-' x length($header) ) . "\n"
        . $commits . "\n\n";
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
            my $log = run( qw(git log --oneline -1), $shas->{$branch} );
            my ($msg) = ( $log =~ /^\w+\s+([^\n]+)/ );
            push @out, sprintf "  %-35s %s   %s", $branch,
                substr( $shas->{$branch}, 0, 8 ), $msg;
        }
        push @out, '';

    }
    return join "\n", @out;
}

#===================================
sub checkout_to {
#===================================
    my ( $self, $destination ) = @_;

    my $name = $self->name;
    eval {
        run qw(git clone), $self->git_dir, $destination;
        1;
    }
    or die "Error checking out repo <$name>: $@";
}

#===================================
sub name          { shift->{name} }
sub git_dir       { shift->{git_dir} }
sub url           { shift->{url} }
sub tracker       { shift->{tracker} }
sub reference_dir { shift->{reference_dir} }
#===================================

1
