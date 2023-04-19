package ES::Book;

use strict;
use warnings;
use v5.10;
use Data::Dumper qw(Dumper);
use ES::Util
    qw(run build_chunked build_single proc_man write_html_redirect $Opts);
use Path::Class();
use ES::Source();
use File::Copy::Recursive qw(fcopy rcopy);
use ES::Toc();
use utf8;
use List::Util qw(first);

our %Page_Header = (
    en => {
        old => <<"HEADER",
A newer version is available. For the latest information, see the
<a href="../current/index.html">current release documentation</a>.
HEADER
        dead => <<"HEADER",
<strong>IMPORTANT</strong>: No additional bug fixes or documentation updates
will be released for this version. For the latest information, see the
<a href="../current/index.html">current release documentation</a>.
HEADER
        new => <<"HEADER"
You are looking at preliminary documentation for a future release.
Not what you want? See the
<a href="../current/index.html">current release documentation</a>.
HEADER
    },
    zh_cn => {
        old => <<"HEADER",
你当前正在查看的是旧版本的文档。如果不是你要找的，请点击查看 <a href="../current/index.html">当前发布版本的文档</a>。
HEADER
        dead => <<"HEADER",
你当前正在查看的是旧版本的文档。如果不是你要找的，请点击查看 <a href="../current/index.html">当前发布版本的文档</a>。
HEADER
        new => <<"HEADER"
你当前正在查看的是未发布版本的预览版文档。如果不是你要找的，请点击查看 <a href="../current/index.html">当前发布版本的文档</a>。
HEADER
    },
    ja => {
        old => <<"HEADER",
A newer version is available. For the latest information, see the
<a href="../current/index.html">current release documentation</a>.
HEADER
        dead => <<"HEADER",
<strong>IMPORTANT</strong>: No additional bug fixes or documentation updates
will be released for this version. For the latest information, see the
<a href="../current/index.html">current release documentation</a>.
HEADER
        new => <<"HEADER"
You are looking at preliminary documentation for a future release.
Not what you want? See the
<a href="../current/index.html">current release documentation</a>.
HEADER
    },
    ko => {
        old => <<"HEADER",
A newer version is available. For the latest information, see the
<a href="../current/index.html">current release documentation</a>.
HEADER
        dead => <<"HEADER",
<strong>IMPORTANT</strong>: No additional bug fixes or documentation updates
will be released for this version. For the latest information, see the
<a href="../current/index.html">current release documentation</a>.
HEADER
        new => <<"HEADER"
You are looking at preliminary documentation for a future release.
Not what you want? See the
<a href="../current/index.html">current release documentation</a>.
HEADER
        }

);

#===================================
sub new {
#===================================
    my ( $class, %args ) = @_;

    my $title = $args{title}
        or die "No <title> specified: " . Dumper( \%args );

    my $source = ES::Source->new(
        temp_dir => $args{temp_dir},
        sources  => $args{sources},
        examples => $args{examples},
    );

    my $prefix = $args{prefix}
        or die "No <prefix> specified for book <$title>";

    my $index = Path::Class::file( $args{index} || 'index.asciidoc' );

    my $chunk = $args{chunk} || 0;
    my $toc   = $args{toc}   || 0;

    my $branch_list = $args{branches};
    my $current     = $args{current};

    die "<branches> must be an array in book <$title>"
        unless ref $branch_list eq 'ARRAY';

    # Each branch can be either a single value, or a mapping of
    # {<branch_name>: <title>}. Branch titles are used in the version dropdown
    # and version lists.
    my ( @branches, %branch_titles );
    for (@$branch_list) {
        my ( $branch, $title ) = ref $_ eq 'HASH' ? (%$_) : ( $_, $_ );
        push @branches, $branch;
        $branch_titles{$branch} = $title;
    }

    die "Current branch <$current> is not in <branches> in book <$title>"
        unless $branch_titles{$current};

    my $live_branches = $args{live};
    # If `live` is defined, check if there are any specified branches that
    # aren't in the list of branches being built.
    my @difference;
    foreach my $item (@$live_branches) {
        push @difference, $item unless grep { $item eq $_ } @branches;
    }

    # print "Branches: ", join(", ", @branches), "\n";
    # print "Live: ", join(", ", @$live_branches), "\n";
    # print "Difference: ", join(", ", @difference), "\n";

    my $missing = join ", ", @difference;
    die "Live branch(es) <$missing> not in <branches> in book <$title>"
        if $difference[0];

    my $tags = $args{tags}
        or die "No <tags> specified for book <$title>";

    my $subject = $args{subject}
        or die "No <subject> specified for book <$title>";

    my $collection = $args{collection}
        or die "No <collection> specified for book <$title>";

    my $group = $args{group} || '';

    my $book_id = $args{book_id}
        or die "No <book_id> specified for book <$title>";

    my $lang = $args{lang} || 'en';

    my $respect_edit_url_overrides = 0;
    if (exists $args{respect_edit_url_overrides}) {
        $respect_edit_url_overrides = $args{respect_edit_url_overrides};
        if ($respect_edit_url_overrides eq 'true') {
            $respect_edit_url_overrides = 1;
        } elsif ($respect_edit_url_overrides eq 'false') {
            $respect_edit_url_overrides = 0;
        } else {
            die 'respect_edit_url_overrides must be true or false but was ' . $respect_edit_url_overrides;
        }
    }

    bless {
        title         => $title,
        raw_dir       => $args{raw_dir}->subdir( $prefix ),
        dir           => $args{dir}->subdir( $prefix ),
        temp_dir      => $args{temp_dir},
        source        => $source,
        prefix        => $prefix,
        chunk         => $chunk,
        toc           => $toc,
        single        => $args{single},
        index         => $index,
        branches      => \@branches,
        live_branches => $args{live} || \@branches,
        branch_titles => \%branch_titles,
        current       => $current,
        tags          => $tags,
        subject       => $subject,
        collection    => $collection,
        group         => $group,
        book_id       => $book_id,
        private       => $args{private} || '',
        noindex       => $args{noindex} || '',
        lang          => $lang,
        respect_edit_url_overrides => $respect_edit_url_overrides,
        suppress_migration_warnings => $args{suppress_migration_warnings} || 0,
        toc_extra => $args{toc_extra} || '',
    }, $class;
}

#===================================
sub build {
#===================================
    my ( $self, $rebuild, $conf_path ) = @_;

    my $toc_extra = $self->{toc_extra} ? $conf_path->parent->file( $self->{toc_extra} ) : 0;
    my $toc = ES::Toc->new( $self->title, $toc_extra );
    my $dir = $self->dir;
    $dir->mkpath;

    my $title = $self->title;

    my $pm = proc_man(
        $Opts->{procs},
        sub {
            my ( $pid, $error, $branch ) = @_;
            $self->source->mark_done( $title, $branch );
        }
    );

    my $latest = !$self->{suppress_migration_warnings};
    my $update_version_toc = 0;
    my $rebuilding_current_branch = 0;
    for my $branch ( @{ $self->branches } ) {
        my $building = $self->_build_book( $branch, $pm, $rebuild, $latest );
        $update_version_toc ||= $building;
        $latest = 0;

        my $version = $self->branch_title($branch);
        if ( $branch eq $self->current ) {  # TODO: when "current" is a version, change this.
            $toc->add_entry(
                {   title => "$title: $version (current)",
                    url   => "current/index.html"
                }
            );
            $rebuilding_current_branch = $building;
        }
        else {
            $toc->add_entry(
                {   title => "$title: $version",
                    url   => "$version/index.html"
                }
            );
        }
    }
    $pm->wait_all_children();
    $self->_copy_branch_to_current if $rebuilding_current_branch;
    $update_version_toc |= $self->_remove_old_versions;
    if ( $self->is_multi_version ) {
        if ( $update_version_toc ) {
            # We could get away with only doing this if we added or removed
            # any branches or changed the current branch, but we don't have
            # that information right now.
            $toc->write( $self->{raw_dir}, $dir, $self->{temp_dir} );
            for ( @{ $self->branches } ) {
                my $version = $self->branch_title($_);
                $self->_update_title_and_version_drop_downs( $dir->subdir( $version ), $_ );
            }
            $self->_update_title_and_version_drop_downs( $dir->subdir( 'current' ) , $self->current );
            for ( @{ $self->branches } ) {
                my $version = $self->branch_title($_);
                $self->_update_title_and_version_drop_downs( $self->{raw_dir}->subdir( $version ), $_ );
            }
            $self->_update_title_and_version_drop_downs( $self->{raw_dir}->subdir( 'current' ) , $self->current );
        }
        return {
            title => "$title [" . $self->branch_title( $self->current ) . "\\]",
            url   => $self->prefix . '/current/index.html',
            versions      => $self->prefix . '/index.html',
            section_title => $self->section_title()
        };
    }
    if ( $update_version_toc ) {
        write_html_redirect( $dir, "current/index.html" );
    }
    return {
        title => $title,
        url   => $self->prefix . '/current/index.html'
    };
}

#===================================
# Fork a process to build the book if it needs to be built. Returns 0
# immediately if the book doesn't have to be built. Forks and then returns 1
# immediately if the book *does* have to be built. To get the success or
# failure of the build you must wait on the $pm argument for the children to
# join the parent process.
#
# branch  - The branch being built  ## TODO: Change to `version`
# pm      - ProcessManager for forking
# rebuild - if truthy then we rebuild the book regardless of changes.
# latest  - is this the latest branch of the book?
#===================================
sub _build_book {
#===================================
    my ( $self, $branch, $pm, $rebuild, $latest ) = @_;

    my $version       = $self->branch_title($branch);
    my $raw_version_dir = $self->{raw_dir}->subdir( $version );
    my $version_dir    = $self->dir->subdir($version);
    my $source        = $self->source;
    my $index         = $self->index;
    my $section_title = $self->section_title($version);
    my $subject       = $self->subject;
    my $collection    = $self->collection;
    my $group         = $self->group;
    my $book_id       = $self->book_id;
    my $current       = $self->current;
    my $lang          = $self->lang;

    return 0 unless $rebuild ||
        $source->has_changed( $self->title, $branch );

    my ( $checkout, $edit_urls, $first_path, $alternatives, $roots ) =
        $source->prepare($self->title, $branch);

    $pm->start($branch) and return 1;
    printf(" - %40.40s: Building %s...\n", $self->title, $version);
    eval {
        if ( $self->single ) {
            build_single(
                $first_path->file($index),
                $raw_version_dir,
                $version_dir,
                version       => $version,
                lang          => $lang,
                edit_urls     => $edit_urls,
                private       => $self->private( $branch ),
                noindex       => $self->noindex( $branch ),
                multi         => $self->is_multi_version,
                page_header   => $self->_page_header($branch),
                section_title => $section_title,
                subject       => $subject,
                collection    => $collection,
                group         => $group,
                book_id       => $book_id,
                current       => $current,
                toc           => $self->toc,
                resource      => [$checkout],
                latest        => $latest,
                respect_edit_url_overrides => $self->{respect_edit_url_overrides},
                alternatives  => $alternatives,
                branch => $branch,
                roots => $roots,
                relativize => 1,
            );
        }
        else {
            build_chunked(
                $first_path->file($index),
                $raw_version_dir,
                $version_dir,
                version       => $version,
                lang          => $lang,
                edit_urls     => $edit_urls,
                private       => $self->private( $branch ),
                noindex       => $self->noindex( $branch ),
                chunk         => $self->chunk,
                multi         => $self->is_multi_version,
                page_header   => $self->_page_header($branch),
                section_title => $section_title,
                subject       => $subject,
                collection    => $collection,
                group         => $group,
                book_id       => $book_id,
                current       => $current,
                resource      => [$checkout],
                latest        => $latest,
                respect_edit_url_overrides => $self->{respect_edit_url_overrides},
                alternatives  => $alternatives,
                branch => $branch,
                roots => $roots,
                relativize => 1,
            );
        }
        $checkout->rmtree;
        printf(" - %40.40s: Finished %s\n", $self->title, $version);

        1;
    } && $pm->finish;
    # NOTE: This method is about a screen up with $pm->start so it doesn't
    # return *anything* here. It just dies if there was a failure so we can
    # pick that up in the parent process.

    my $error = $@;
    die "\nERROR building "
        . $self->title
        . " version $version\n\n"
        . $source->dump_recent_commits( $self->title, $branch )
        . $error . "\n";
}

#===================================
sub _update_title_and_version_drop_downs {
#===================================
    my ( $self, $version_dir, $branch ) = @_;

    my $title = '<li id="book_title"><span>' . $self->title . ': ';
    $title .= '<select id="live_versions">';
    my $removed_any = 0;
    for my $b ( @{ $self->branches } ) {
        my $live = grep( /^$b$/, @{ $self->{live_branches} } );
        unless ( $live || $branch eq $b ) {
            $removed_any = 1;
            next;
        }
        my $version = $self->branch_title($b);

        $title .= '<option value="' . $version . '"';
        $title .= ' selected'  if $branch eq $b;
        $title .= '>' . $version;
        $title .= ' (current)' if $self->current eq $b;  # TODO: change when "current" is a version
        $title .= '</option>';
    }
    $title .= '<option value="other">other versions</option>' if $removed_any;
    $title .= '</select>';
    if ( $removed_any ) {
        $title .= '<span id="other_versions">other versions: <select>';
        for my $b ( @{ $self->branches } ) {
            my $version = $self->branch_title($b);

            $title .= '<option value="' . $version . '"';
            $title .= ' selected'  if $branch eq $b;
            $title .= '>' . $version;
            $title .= ' (current)' if $self->current eq $b; # TODO: change when "current" is a version
            $title .= '</option>';
        }
        $title .= '</select>';
    }
    $title .= '</span></li>';
    for ( 'toc.html', 'index.html' ) {
        my $file = $version_dir->file($_);
        # Ignore missing files because the books haven't been built yet. This
        # can happen after a new branch is added to the config and then we use
        # --keep_hash to prevent building new books, like for PR tests.
        next unless -e $file;

        my $html = $file->slurp( iomode => "<:encoding(UTF-8)" );

        # If a book uses a custom index page, it may not include the TOC. The
        # substitution below will fail, so we abort early in this case.
        next unless ($_ == 'index.html' && ($html =~ /ul class="toc"/));

        my $success = ($html =~ s/<ul class="toc">(?:<li id="book_title">.+?<\/li>)?\n?<li>/<ul class="toc">${title}<li>/);
        die "couldn't update version" unless $success;
        $file->spew( iomode => '>:utf8', $html );
    }
}

#===================================
sub _copy_branch_to_current {
#===================================
    my ( $self ) = @_;

    # TODO: current should be a version, not a branch
    my $version_dir  = $self->{dir}->subdir( $self->branch_title( $self->current ) );
    my $current_dir = $self->{dir}->subdir('current');
    my $raw_version_dir  = $self->{raw_dir}->subdir( $self->branch_title( $self->current ) );
    my $raw_current_dir = $self->{raw_dir}->subdir('current');

    $current_dir->rmtree;
    rcopy( $version_dir, $current_dir )
        or die "Couldn't copy <$version_dir> to <$current_dir>: $!";
    $raw_current_dir->rmtree;
    rcopy( $raw_version_dir, $raw_current_dir )
        or die "Couldn't copy <$raw_version_dir> to <$raw_current_dir>: $!";
}

#===================================
sub _page_header {
#===================================
    my ( $self, $branch ) = @_;
    return '' unless $self->is_multi_version;

    my $current = $self->current;
    return '' if $current eq $branch;

    # Find the positions of the branch being built ($branch) and the current
    # branch ($current) in the list of branches for this book.
    my @branches = @{$self->branches};
    my $branchidx = first { $branches[$_] eq $branch } 0..$#branches;
    my $currentidx = first { $branches[$_] eq $current } 0..$#branches;

    # Old branches are "later" in the list than the current branch;
    my $key = $branchidx > $currentidx ? 'old' : 'new';
    $key = 'dead' if $key eq 'old' && !grep( /^$branch$/, @{ $self->{live_branches} } );

    return $self->_page_header_text( $key );
}

#===================================
sub _page_header_text {
#===================================
    my ( $self, $phrase ) = @_;
    $phrase ||= '';
    return $Page_Header{ $self->lang }{$phrase}
        || die "No page header available for lang: "
        . $self->lang
        . " and phrase: $phrase";

}

#===================================
# Remove all files for versions that have been removed.
#
# Versions are the `branch_title`s of each branch. We also want to keep the `current` version.
#===================================
sub _remove_old_versions {
#===================================
    my $self     = shift;
    my $dir      = $self->dir;

    my %versions = map { $self->branch_title($_) => 1 } ( @{ $self->branches } );
    $versions{'current'} = 1;
    my $removed_any = 0;

    for my $child ( $dir->children ) {
        next unless $child->is_dir;
        my $version = $child->basename;
        # Don't delete any version that is "current" or in the list of branches.
        next if $versions{$version};
        printf(" - %40.40s: Deleting old branch %s\n", $self->title, $version);
        $child->rmtree;
        $removed_any = 1;
    }
    return $removed_any;
}

#===================================
sub section_title {
#===================================
    my $self   = shift;
    my $version = shift || '';
    my $title  = $self->tags;
    return $title unless $self->is_multi_version;
    return $title . "/" . $version;
}

#===================================
sub noindex {
#===================================
    my ( $self, $branch ) = @_;
    return 1 if $self->{noindex};
    return 0 if grep( /^$branch$/, @{ $self->{live_branches} } );
    return 1;
}

#===================================
sub private {
#===================================
    my ( $self, $branch ) = @_;
    return 1 if $self->{private};
    return 0 if $branch =~ /^(master|main)$/;
    return 0 if grep( /^$branch$/, @{ $self->{live_branches} } );
    return 1;
}


#===================================
sub title            { shift->{title} }
sub dir              { shift->{dir} }
sub prefix           { shift->{prefix} }
sub chunk            { shift->{chunk} }
sub toc              { shift->{toc} }
sub single           { shift->{single} }
sub index            { shift->{index} }
sub branches         { shift->{branches} }
sub branch_title     { shift->{branch_titles}->{ shift() } }
sub current          { shift->{current} }
sub is_multi_version { @{ shift->branches } > 1 }
sub tags             { shift->{tags} }
sub subject          { shift->{subject} }
sub collection       { shift->{collection} }
sub group            { shift->{group} }
sub book_id          { shift->{book_id} }
sub source           { shift->{source} }
sub lang             { shift->{lang} }
#===================================

1;
