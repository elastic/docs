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
        keep_hash     => $args{keep_hash},
        sub_dirs      => {},
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
            printf(" - %20s: Cloning from <%s>\n", $name, $url);
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
        printf(" - %20s: Upstream has changed to <%s>. Deleting\n", $self->name, $url);
        $git_dir->rmtree;
        return;
    }
    printf(" - %20s: Fetching\n", $self->name);
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
    if ( $self->keep_hash ) {
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

    return $old ne $new if $self->keep_hash;
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
    } elsif ( $self->keep_hash ) {
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

    if ( $self->keep_hash ) {
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

    my $description = $self->name . "/$title:$branch:$src_path";
    if ( exists $self->{sub_dirs}->{$branch} ) {
        return "Used " . $self->{sub_dirs}->{$branch} .
                " for $description\n";
    }

    local $ENV{GIT_DIR} = $self->git_dir;
    my $start = $self->_last_commit( $title, $branch, $src_path );
    my $rev_range = $self->keep_hash ? $start : "$start...$branch";

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
sub checkout_to {
#===================================
    my ( $self, $destination ) = @_;

    die 'sub_dir not supported with checkout_to' if %{ $self->{sub_dirs}};
    my $name = $self->name;
    eval {
        run qw(git clone), $self->git_dir, $destination;
        1;
    }
    or die "Error checking out repo <$name>: $@";
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
sub name          { shift->{name} }
sub git_dir       { shift->{git_dir} }
sub url           { shift->{url} }
sub tracker       { shift->{tracker} }
sub reference_dir { shift->{reference_dir} }
sub keep_hash     { shift->{keep_hash} }
#===================================

1
