package ES::Book;

use strict;
use warnings;
use v5.10;
use Data::Dumper qw(Dumper);
use ES::Util qw(run build_chunked build_single write_html_redirect);
use Path::Class();
use ES::Repo();
use File::Copy::Recursive qw(fcopy rcopy);
use ES::Toc();

#===================================
sub new {
#===================================
    my ( $class, %args ) = @_;

    my $title = $args{title}
        or die "No <title> specified: " . Dumper( \%args );

    my $dir = $args{dir}
        or die "No <dir> specified for book <$title>";

    my $repo = ES::Repo->get_repo( $args{repo} );

    my $prefix = $args{prefix}
        or die "No <prefix> specified for book <$title>";

    my $index = $args{index}
        or die "No <index> specfied for book <$title>";

    my $chunk     = $args{chunk}     || 0;
    my $toc_level = $args{toc_level} || 1;
    my $toc       = $args{toc}       || 0;

    my $branches = $args{branches} || $repo->branches;
    my $current  = $args{current}  || $repo->current;

    die "<branches> must be an array in book <$title>"
        unless ref $branches eq 'ARRAY';

    die "Current branch <$current> is not in <branches> in book <$title>"
        unless grep { $current eq $_ } @$branches;

    my $template = $args{template}
        or die "No <template> specified for book <$title>";

    bless {
        title     => $title,
        dir       => $dir->subdir($prefix),
        template  => $template,
        repo      => $repo,
        prefix    => $prefix,
        chunk     => $chunk,
        toc       => $toc,
        toc_level => $toc_level,
        single    => $args{single},
        index     => Path::Class::file($index),
        branches  => $branches,
        current   => $current
    }, $class;
}

#===================================
sub build {
#===================================
    my $self = shift;

    say "Book: " . $self->title;

    my $repo        = $self->repo;
    my $branches    = $self->branches;
    my $current     = $self->current;
    my $current_url = 'current/index.html';
    my $index       = $self->index;
    my $src_path    = $index->parent;
    my $toc         = ES::Toc->new( $self->title );
    my $dir         = $self->dir;
    my $chunk       = $self->chunk;
    my $toc_level   = $self->toc_level;
    my $add_toc     = $self->toc;

    $dir->mkpath;

    my $multi = @$branches > 1;
    for my $branch (@$branches) {

        say " - Branch: $branch";

        my $branch_dir = $dir->subdir($branch);
        my $edit_url = $self->repo->edit_url( $branch, $index );

        my $changed
            = !-e $branch_dir
            || $self->template->md5_changed($branch_dir)
            || $repo->has_changed( $src_path, $branch );

        if ($changed) {
            say "   - Building";
            $repo->checkout( $src_path, $branch );
            if ( $self->single ) {
                $branch_dir->rmtree;
                $branch_dir->mkpath;
                build_single(
                    $repo->dir->file($index),
                    $branch_dir,
                    version  => $branch,
                    multi    => $multi,
                    edit_url => $edit_url,
                    toc      => $add_toc,
                    template => $self->template
                );
            }
            else {
                build_chunked(
                    $repo->dir->file($index),
                    $branch_dir,
                    chunk     => $chunk,
                    toc_level => $toc_level,
                    version   => $branch,
                    multi     => $multi,
                    edit_url  => $edit_url,
                    template => $self->template
                );
            }
            $repo->mark_done( $src_path, $branch );
        }
        else {
            say "   - Reusing existing";
        }

        my $url   = $branch . '/index.html';
        my $title = 'Version: ' . $branch;

        if ( $branch eq $current ) {
            say "   - Copying to current";
            $url = $current_url;
            $title .= ' (current)';
            my $current_dir = $dir->subdir('current');
            $current_dir->rmtree;
            rcopy( $branch_dir, $current_dir )
                or die "Couldn't copy <$branch_dir> to <$current_dir>: $!";
        }
        $toc->add_entry( { title => $title, url => $url } );
    }

    my $versions = $self->prefix . '/index.html';
    if ( @$branches > 1 ) {
        say " - Writing versions TOC";
        $toc->write($dir);
    }
    else {
        say " - Writing redirect to current branch";
        write_html_redirect( $dir, $current_url );
        undef $versions;
    }

    $self->remove_old_branches;

    return {
        title => $self->title . ( $versions ? " -- $current" : '' ),
        url      => $self->prefix . '/current/index.html',
        versions => $versions,
    };
}

#===================================
sub remove_old_branches {
#===================================
    my $self     = shift;
    my %branches = map { $_ => 1 } ( @{ $self->branches }, 'current' );
    my $dir      = $self->dir;

    for my $child ( $dir->children ) {
        next unless $child->is_dir;
        my $version = $child->basename;
        next if $branches{$version};
        say " - Deleting old branch: $version";
        $child->rmtree;
    }
}

#===================================
sub title     { shift->{title} }
sub dir       { shift->{dir} }
sub template  { shift->{template} }
sub repo      { shift->{repo} }
sub prefix    { shift->{prefix} }
sub chunk     { shift->{chunk} }
sub toc       { shift->{toc} }
sub toc_level { shift->{toc_level} }
sub single    { shift->{single} }
sub index     { shift->{index} }
sub branches  { shift->{branches} }
sub current   { shift->{current} }
#===================================

1;
