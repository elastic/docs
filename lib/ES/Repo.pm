package ES::Repo;

use strict;
use warnings;
use v5.10;

use Cwd;
use Encode qw(decode_utf8);
use ES::Util qw(run);
use Path::Class();

use parent qw( ES::BaseRepo );

my %Repos;

#===================================
sub new {
#===================================
    my ( $class, %args ) = @_;

    my $self = $class->SUPER::new(%args);

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
# Returns 'not_changed' if the repo hasn't changed since we last built it,
# 'changed' if it has, and 'new_sub_dir' if this is a sub_dir for a new source.
#===================================
sub has_changed {
#===================================
    my $self = shift;
    my ( $title, $branch, $path, $asciidoctor ) = @_;

    $path = $self->normalize_path( $path, $branch );
    $branch = $self->normalize_branch( $branch );

    local $ENV{GIT_DIR} = $self->git_dir;
    my $old_info = $self->_last_commit_info(@_);

    my $new;
    if ( $self->{keep_hash} ) {
        # If we're keeping the hash from the last build but there *isn't* a
        # hash that means that the branch wasn't used the last time we built
        # this book. That means we'll skip it entirely when building the book
        # anyway so we should consider the book not to have changed.
        unless ($old_info) {
            # New sub_dirs *might* build, but only if the entire book is built
            # out of new sub_dirs.
            return 'new_sub_dir' if exists $self->{sub_dirs}->{$branch};
            return 'not_changed';
        }

        $new = $self->_last_commit(@_);
    } else {
        # If we aren't keeping the hash from the last build and there *isn't*
        # a hash that means that this is a new repo so we should build it.
        return 'changed' unless $old_info;

        $new = $self->sha_for_branch( $branch ) or die(
                "Remote branch <origin/$branch> doesn't exist in repo "
                . $self->name);
    }
    my $new_info = $new;
    $new_info .= '|asciidoctor' if $asciidoctor;

    # We check sub_dirs *after* the checks above so we can handle sub_dir for
    # new sources specially.
    return 'changed' if exists $self->{sub_dirs}->{$branch};

    if ($self->{keep_hash}) {
        return $old_info ne $new_info ? 'changed' : 'not_changed';
    }
    return 'not_changed' if $old_info eq $new_info;
    # If the asciidoctor-ness of the previous build doesn't match this one then
    # we've changed. It'd be nice if build-info were a class but we'll be
    # dropping asciidoctor as soon as we've migrated all of the books and this
    # is sort of a local minima of effort.
    return 'changed' unless ($old_info =~ /\|asciidoctor$/) == $asciidoctor;

    my $changed;
    eval {
        $changed = !!run qw(git diff --shortstat),
                         $self->_last_commit(@_), $new,
                         '--', $path;
        1;
    }
        || do { $changed = 1 };

    return $changed ? 'changed' : 'not_changed';
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
        $new = $self->sha_for_branch( $branch );
    }
    $new .= '|asciidoctor' if $asciidoctor;

    $self->tracker->set_sha_for_branch( $self->name,
        $self->_tracker_branch(@_), $new );
}

#===================================
sub prepare {
#===================================
    my $self = shift;
    my ( $title, $branch, $path, $dest_root, $prefix ) = @_;
    my $dest = $dest_root->subdir( $prefix );

    if ( exists $self->{sub_dirs}->{$branch} ) {
        $self->_prepare_sub_dir( $title, $branch, $path, $dest );
        return $dest;
    }

    my $resolved_branch = $self->_resolve_branch( @_ );
    unless ( $resolved_branch ) {
        printf(" - %40.40s: Skipping new repo %s for branch %s.\n",
               $title, $self->{name}, $branch);
        return $dest;
    }

    $self->_extract_from_ref( $dest, $branch, $path );
    return $dest;
}

#===================================
sub _prepare_sub_dir {
#===================================
    my ( $self, $title, $branch, $path, $dest ) = @_;
    my $source_root = $self->{sub_dirs}->{$branch};

    unless ( $self->{keep_hash} ) {
        $self->_extract_from_dir( $source_root, $dest, $path );
        return $dest;
    }

    my $no_uncommitted_changes = eval {
        local $ENV{GIT_WORK_TREE} = $source_root;
        local $ENV{GIT_DIR} = $ENV{GIT_WORK_TREE} . '/.git';
        run qw(git diff-index --quiet HEAD --);
        1;
    };
    unless ( $no_uncommitted_changes ) {
        unless ( $@ =~ /\n---out---\n\n---err---\n\n---------\n/) {
            # If the error message isn't empty then something went wrong checking.
            die "failed to check for outstanding commits: $@";
        }
        printf(" - %40.40s: Not merging the subbed dir for [%s][%s][%s] because it has uncommitted changes.\n",
                $title, $self->{name}, $branch, $path);
        $self->_extract_from_dir( $source_root, $dest, $path );
        return $dest;
    }

    my $resolved_branch = $self->_resolve_branch( $title, $branch, $path );
    unless ( $resolved_branch ) {
        printf(" - %40.40s: Not merging the subbed dir for [%s][%s][%s] because it is new.\n",
                $title, $self->{name}, $branch, $path);
        $self->_extract_from_dir( $source_root, $dest, $path );
        return $dest;
    }

    local $ENV{GIT_DIR} = "$source_root/.git";
    my $subbed_head = run qw(git rev-parse HEAD);
    delete local $ENV{GIT_DIR};
    my $merge_branch = "${resolved_branch}_${subbed_head}_$path";
    $merge_branch =~ s|/|_|g;

    # Check if we've already merged this path by looking for the merged_branch
    # in the source repo. This is safe because:
    # 1. We prune all branches from the source repo before the build.
    # 2. The merge branch contains the hash of the subbed head.
    my $already_built = eval { 
        local $ENV{GIT_DIR} = $self->{git_dir};
        run qw(git rev-parse), $merge_branch;
        1;
    };
    if ( $already_built ) {
        # Logging here would be pretty noisy.
        $self->_extract_from_ref( $dest, $merge_branch, $path );
        return;
    }

    # Merge the HEAD of the subbed dir into the commit that last successfully
    # built the docs.
    printf(" - %40.40s: Merging the subbed dir for [%s][%s][%s] into the last successful build.\n",
            $title, $self->{name}, $branch, $path);
    my $work = Path::Class::dir( '/tmp/mergework' );
    $work->rmtree;
    run qw(git clone --no-checkout), $self->{git_dir}, $work;
    my $original_pwd = Cwd::cwd();
    chdir $work;
    my $merged = eval {
        run qw(git remote add subbed_repo), $source_root;
        run qw(git fetch subbed_repo), $subbed_head;
        run qw(git remote remove subbed_repo);
        run qw(git config core.sparseCheckout true);
        $self->_write_sparse_config( $work, $path );
        run qw(git checkout -b), $merge_branch, $resolved_branch;
        run qw(git merge -m merge), $subbed_head;
        run qw(git push origin -f), $merge_branch; # Origin here is just our clone.
        1;
    };
    chdir $original_pwd;
    unless ( $merged ) {
        printf(" - %40.40s: Failed to merge the subbed dir for [%s][%s][%s] into the last successful build:\n%s",
                $title, $self->{name}, $branch, $path, $@);
        $dest->rmtree;
        $self->_extract_from_dir( $source_root, $dest, $path );
        return $dest;
    }
    printf(" - %40.40s: Merged the subbed dir for [%s][%s][%s] into the last successful build.\n",
            $title, $self->{name}, $branch, $path);
    $self->_extract_from_ref( $dest, $merge_branch, $path );
}

#===================================
sub _extract_from_dir {
#===================================
    my ( $self, $source_root, $dest_root, $path ) = @_;

    # Copies the $path from the subsitution directory. It is tempting to
    # just symlink the substitution directory into the destination and
    # call it a day and that *almost* works! The trouble is that we often
    # use relative paths to include asciidoc files from other repositories
    # and those relative paths don't work at all with symlinks.
    my $source = $source_root->file( $path );
    die "Can't find $source" unless -e $source;
    my $dest = $dest_root->subdir( $path )->parent;
    $dest->mkpath;
    eval {
        run qw(cp -r), $source, $dest;
        1;
    } or die "Error copying from $source: $@";
}

#===================================
sub _extract_from_ref {
#===================================
    my ( $self, $dest, $ref, $path ) = @_;
    local $ENV{GIT_DIR} = $self->{git_dir};

    $dest->mkpath;
    my $tar = $dest->file( '.temp_git_archive.tar' );
    die "File <$tar> already exists" if -e $tar;
    run qw(git archive --format=tar -o), $tar, $ref, $path;

    run qw(tar -x -C), $dest, '-f', $tar;
    $tar->remove;
}

#===================================
sub _tracker_branch {
#===================================
    my $self   = shift;
    my $title  = shift or die "No <title> specified";
    my $branch = shift or die "No <branch> specified";
    my $path   = shift or die "No <path> specified";
    $path = $self->normalize_path( $path, $branch );
    return "$title/${path}/${branch}";
}

#===================================
sub edit_url {
#===================================
    my ( $self, $branch ) = @_;

    $branch = $self->normalize_branch( $branch );
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

    $branch = $self->normalize_branch( $branch );
    $src_path = $self->normalize_path( $src_path, $branch );
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
            = decode_utf8 run( 'git', 'log',
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
sub show_file {
#===================================
    my $self = shift;
    my ( $reason, $branch, $file ) = @_;

    if ( exists $self->{sub_dirs}->{$branch} ) {
        my $realpath = $self->{sub_dirs}->{$branch}->file($file);
        return $realpath->slurp( iomode => "<:encoding(UTF-8)" );
    }

    my $resolved_branch = $self->_resolve_branch( @_ );
    die "Can't resolve $branch" unless $resolved_branch;

    local $ENV{GIT_DIR} = $self->git_dir;
    return decode_utf8 run( qw (git show ), $resolved_branch . ':' . $file );
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
# Converts a branch specification into the branch to actually use in the git
# repo. Returns falsy if we've been instructed to keep the hash used by the
# last build but we have yet to use the branch.
#===================================
sub _resolve_branch {
#===================================
    my $self = shift;
    my ( $title, $branch, $path ) = @_;

    return $branch unless $self->{keep_hash};

    $branch = $self->_last_commit(@_);
    die "--keep_hash can't build on top of --sub_dir" if $branch eq 'local';
    return $branch;
}

#===================================
sub add_source {
#===================================
    my ( $self, $sources, $prefix, $path, $exclude, $map_branches, $private, $alternatives ) = @_;

    push @$sources, {
        repo => $self,
        prefix => $prefix,
        path => $path,
        exclude => $exclude,
        map_branches => $map_branches,
        private => $private,
        alternatives => $alternatives,
    };
}


#===================================
sub tracker       { shift->{tracker} }
#===================================

1
