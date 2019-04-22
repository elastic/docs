package ES::Repo;

use strict;
use warnings;
use v5.10;

use Path::Class();
use Encode qw(decode_utf8);
use ES::Util qw(run sha_for);

use base qw( ES::BaseRepo );

my %Repos;

#===================================
sub new {
#===================================
    my ( $class, %args ) = @_;

    my $self = shift->SUPER::new(%args);

    my $name = $self->name;
    $self->{tracker} = $args{tracker}
        or die "No <tracker> specified for repo <$name>";
    $self->{keep_hash} = $args{keep_hash};
    $Repos{$self->name} = $self;
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
sub add_sub_dir {
#===================================
    my ( $self, $branch, $dir ) = @_;
    $self->{sub_dirs}->{$branch} = $dir;
    return ();
}

#===================================
sub has_changed {
#===================================
    my $self = shift;
    my ( $title, $branch, $path, $asciidoctor ) = @_;

    return 1 if exists $self->{sub_dirs}->{$branch};

    local $ENV{GIT_DIR} = $self->git_dir;
    my $old = $self->_last_commit_info(@_);

    my $new;
    if ( $self->{keep_hash} ) {
        # If we're keeping the hash from the last build but there *isn't* a
        # hash that means that the branch wasn't used the last time we built
        # this book. That means we'll skip it entirely when building the book
        # anyway so we should consider the book not to have changed.
        return 0 unless $old;

        $new = $self->_last_commit(@_);
    } else {
        # If we aren't keeping the hash from the last build and there *isn't*
        # a hash that means that this is a new repo so we should build it.
        return 1 unless $old;

        $new = sha_for($branch) or die(
                "Remote branch <origin/$branch> doesn't exist in repo "
                . $self->name);
    }
    $new .= '|asciidoctor' if $asciidoctor;

    return $old ne $new if $self->{keep_hash};
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
    my ( $title, $branch, $path, $asciidoctor ) = @_;

    my $new;
    if ( exists $self->{sub_dirs}->{$branch} ) {
        $new = 'local';
    } elsif ( $self->{keep_hash} ) {
        $new = $self->_last_commit($title, $branch, $path);
        return unless $new; # Skipped if nil
    } else {
        local $ENV{GIT_DIR} = $self->git_dir;
        $new = sha_for($branch);
    }
    $new .= '|asciidoctor' if $asciidoctor;

    $self->tracker->set_sha_for_branch( $self->name,
        $self->_tracker_branch(@_), $new );
}

#===================================
sub extract {
#===================================
    my $self = shift;
    my ( $title, $branch, $path, $dest ) = @_;

    if ( exists $self->{sub_dirs}->{$branch} ) {
        # Copies the $path from the subsitution diretory. It is tempting to
        # just symlink the substitution directoriy into the destionation and
        # call it a day and that *almost* works! The trouble is that we often
        # use relative paths to include asciidoc files from other repositories
        # and those relative paths don't work at all with symlinks.
        my $realpath = $self->{sub_dirs}->{$branch}->subdir($path);
        my $realdest = $dest->subdir($path)->parent;
        die "Can't find $realpath" unless -e $realpath;
        $realdest->mkpath;
        eval {
            run qw(cp -r), $realpath, $realdest;
            1;
        } or die "Error copying from $realpath: $@";
        return;
    }

    if ( $self->{keep_hash} ) {
        $branch = $self->_last_commit(@_);
        unless ( $branch ) {
            printf(" - %40.40s: %s is new. Skipping\n", $title, $self->{name});
            return;
        }
        die "--keep_hash can't build on top of --sub_dir" if $branch eq 'local';
    }

    local $ENV{GIT_DIR} = $self->git_dir;

    $dest->mkpath;
    my $tar = $dest->file('.temp_git_archive.tar');
    die "File <$tar> already exists" if -e $tar;
    run qw(git archive --format=tar -o ), $tar, $branch, $path;

    run "tar", "-x", "-C", $dest, "-f", $tar;
    $tar->remove;
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

    my $description = $self->name . "/$title:$branch:$src_path";
    if ( exists $self->{sub_dirs}->{$branch} ) {
        return "Used " . $self->{sub_dirs}->{$branch} .
                " for $description\n";
    }

    local $ENV{GIT_DIR} = $self->git_dir;
    my $start = $self->_last_commit( $title, $branch, $src_path );
    my $rev_range = $self->{keep_hash} ? $start : "$start...$branch";

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

    my $header = "Recent commits in $description";
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
        my $shas = $repo->tracker->shas_for_repo( $repo->name );

        next unless %$shas;

        push @out, "Repo: " . $repo->name;
        push @out, '-' x 80;

        local $ENV{GIT_DIR} = $repo->git_dir;

        for my $branch ( sort keys %$shas ) {
            my $sha = $shas->{$branch};
            $sha =~ s/\|.+$//;  # Strip |asciidoctor if it is in the hash
            my $msg;
            if ( $sha eq 'local' ) {
                $msg = 'local changes';
            } else {
                my $log = run( qw(git log --oneline -1), $sha );
                ( $msg ) = $log =~ /^\w+\s+([^\n]+)/;
            } 
            push @out, sprintf "  %-35s %s   %s", $branch,
                substr( $shas->{$branch}, 0, 8 ), $msg;
        }
        push @out, '';

    }
    return join "\n", @out;
}

#===================================
# Information about the last commit, *not* including flags like `asciidoctor.`
#===================================
sub _last_commit {
#===================================
    my $self = shift;
    my $sha = $self->_last_commit_info(@_);
    $sha =~ s/\|.+$//;  # Strip |asciidoctor if it is in the hash
    return $sha;
}

#===================================
# Information about the last commit, including flags like `asciidoctor.`
#===================================
sub _last_commit_info {
#===================================
    my $self = shift;
    my $tracker_branch = $self->_tracker_branch(@_);
    my $sha = $self->tracker->sha_for_branch($self->name, $tracker_branch);
    return $sha;
}

#===================================
sub tracker       { shift->{tracker} }
#===================================

1
