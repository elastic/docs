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
    $index = Path::Class::file($index),;

    my $chunk = $args{chunk} || 0;
    my $toc   = $args{toc}   || 0;

    my $branches = $args{branches} || $repo->branches;
    my $current  = $args{current}  || $repo->current;

    die "<branches> must be an array in book <$title>"
        unless ref $branches eq 'ARRAY';

    die "Current branch <$current> is not in <branches> in book <$title>"
        unless grep { $current eq $_ } @$branches;

    my $template = $args{template}
        or die "No <template> specified for book <$title>";

    bless {
        title    => $title,
        dir      => $dir->subdir($prefix),
        template => $template,
        repo     => $repo,
        prefix   => $prefix,
        chunk    => $chunk,
        toc      => $toc,
        single   => $args{single},
        index    => $index,
        src_path => $index->parent,
        branches => $branches,
        current  => $current
    }, $class;
}

#===================================
sub build {
#===================================
    my $self = shift;

    say "Book: " . $self->title;

    my $toc = ES::Toc->new( $self->title );
    my $dir = $self->dir;
    $dir->mkpath;

    for my $branch ( @{ $self->branches } ) {

        say " - Branch: $branch";
        $self->_build_book($branch);

        if ( $branch eq $self->current ) {
            $self->_copy_branch_to_current($branch);
            $toc->add_entry(
                {   title => "Version: $branch (current)",
                    url   => "current/index.html"
                }
            );

        }
        else {
            $toc->add_entry(
                {   title => "Version: $branch",
                    url   => "$branch/index.html"
                }
            );
        }

    }

    $self->remove_old_branches;

    if ( $self->is_multi_version ) {
        say " - Writing versions TOC";
        $toc->write($dir);
        return {
            title    => $self->title . " [" . $self->current . "\\]",
            url      => $self->prefix . '/current/index.html',
            versions => $self->prefix . '/index.html',
        };
    }

    say " - Writing redirect to current branch";
    write_html_redirect( $dir, "current/index.html" );

    return {
        title => $self->title,
        url   => $self->prefix . '/current/index.html'
    };
}

#===================================
sub _build_book {
#===================================
    my ( $self, $branch ) = @_;

    my $branch_dir = $self->dir->subdir($branch);
    my $repo       = $self->repo;
    my $template   = $self->template;
    my $src_path   = $self->src_path;
    my $index      = $self->index;
    my $edit_url   = $repo->edit_url( $branch, $index );

    return say "   - Reusing existing"
        if -e $branch_dir
        && !$template->md5_changed($branch_dir)
        && !$repo->has_changed( $src_path, $branch );

    say "   - Building";
    $repo->checkout( $src_path, $branch );

    eval {
        if ( $self->single ) {
            $branch_dir->rmtree;
            $branch_dir->mkpath;
            build_single(
                $repo->dir->file($index),
                $branch_dir,
                version  => $branch,
                edit_url => $edit_url,
                multi    => $self->is_multi_version,
                toc      => $self->toc,
                template => $template
            );
        }
        else {
            build_chunked(
                $repo->dir->file($index),
                $branch_dir,
                version  => $branch,
                edit_url => $edit_url,
                chunk    => $self->chunk,
                multi    => $self->is_multi_version,
                template => $template
            );
            $self->_add_title_to_toc( $branch, $branch_dir );
        }
        $repo->mark_done( $src_path, $branch );
        1;
    } && return;

    my $error = $@;
    die "\nERROR building "
        . $self->title
        . " branch $branch\n\n"
        . $repo->dump_recent_commits( $src_path, $branch )
        . $error . "\n";
}

#===================================
sub _add_title_to_toc {
#===================================
    my ( $self, $branch, $dir ) = @_;
    my $title = $self->title;
    if ( $self->is_multi_version ) {
        $title .= ': <select>';
        for ( @{ $self->branches } ) {
            my $option = '<option value="' . $_ . '"';
            $option .= ' selected'  if $branch eq $_;
            $option .= '>' . $_;
            $option .= ' (current)' if $self->current eq $_;
            $option .= '</option>';
            $title  .= $option;
        }
        $title .= '</select>';
    }
    $title = '<li id="book_title"><span>' . $title . '</span></li>';
    for ( 'toc.html', 'index.html' ) {
        my $file = $dir->file($_);
        my $html = $file->slurp( iomode => "<:encoding(UTF-8)" );
        $html =~ s/<ul class="toc"><li>/<ul class="toc">${title}<li>/;
        $file->spew( iomode => '>:utf8', $html );
    }
}

#===================================
sub _copy_branch_to_current {
#===================================
    my ( $self, $branch ) = @_;

    say "   - Copying to current";

    my $branch_dir  = $self->dir->subdir($branch);
    my $current_dir = $self->dir->subdir('current');

    $current_dir->rmtree;
    rcopy( $branch_dir, $current_dir )
        or die "Couldn't copy <$branch_dir> to <$current_dir>: $!";

    return {
        title => "Version: $branch (current)",
        url   => 'current/index.html'
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
        $self->repo->delete_branch( $self->src_path, $version );
    }
}

#===================================
sub title            { shift->{title} }
sub dir              { shift->{dir} }
sub src_path         { shift->{src_path} }
sub template         { shift->{template} }
sub repo             { shift->{repo} }
sub prefix           { shift->{prefix} }
sub chunk            { shift->{chunk} }
sub toc              { shift->{toc} }
sub single           { shift->{single} }
sub index            { shift->{index} }
sub branches         { shift->{branches} }
sub current          { shift->{current} }
sub is_multi_version { @{ shift->branches } > 1 }
#===================================

1;
