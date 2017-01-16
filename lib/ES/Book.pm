package ES::Book;

use strict;
use warnings;
use v5.10;
use Data::Dumper qw(Dumper);
use ES::Util
    qw(run build_chunked build_single proc_man write_html_redirect $Opts);
use Path::Class();
use ES::Repo();
use File::Copy::Recursive qw(fcopy rcopy);
use ES::Toc();

our %Page_Header = (
    en => {
        old => <<"HEADER",
You are looking at documentation for an older release.
Not what you want? See the
<a href="../current/index.html">current release documentation</a>.
HEADER
        new => <<"HEADER"
You are looking at preliminary documentation for a future release.
Not what you want? See the
<a href="../current/index.html">current release documentation</a>.
HEADER
    },
    zh => {
        old => <<"HEADER",
You are looking at documentation for an older release.
Not what you want? See the
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

    my $branch_list = $args{branches} || $repo->branches;
    my $current     = $args{current}  || $repo->current;

    die "<branches> must be an array in book <$title>"
        unless ref $branch_list eq 'ARRAY';

    my ( @branches, %branch_titles );
    for (@$branch_list) {
        my ( $branch, $title ) = ref $_ eq 'HASH' ? (%$_) : ( $_, $_ );
        push @branches, $branch;
        $branch_titles{$branch} = $title;
    }

    die "Current branch <$current> is not in <branches> in book <$title>"
        unless $branch_titles{$current};

    my $template = $args{template}
        or die "No <template> specified for book <$title>";

    my $tags = $args{tags}
        or die "No <tags> specified for book <$title>";

    my $lang = $args{lang} || 'en';

    bless {
        title         => $title,
        dir           => $dir->subdir($prefix),
        template      => $template,
        repo          => $repo,
        prefix        => $prefix,
        chunk         => $chunk,
        toc           => $toc,
        single        => $args{single},
        index         => $index,
        src_path      => $index->parent,
        branches      => \@branches,
        branch_titles => \%branch_titles,
        current       => $current,
        tags          => $tags,
        lang          => $lang
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

    my $title    = $self->title;
    my $src_path = $self->src_path;

    my $pm = proc_man(
        $Opts->{procs},
        sub {
            my ( $pid, $error, $branch ) = @_;
            $self->repo->mark_done( $src_path, $branch );
        }
    );

    for my $branch ( @{ $self->branches } ) {
        $self->_build_book( $branch, $pm );

        my $branch_title = $self->branch_title($branch);
        if ( $branch eq $self->current ) {
            $toc->add_entry(
                {   title => "$title: $branch_title (current)",
                    url   => "current/index.html"
                }
            );

        }
        else {
            $toc->add_entry(
                {   title => "$title: $branch_title",
                    url   => "$branch/index.html"
                }
            );
        }
    }
    $pm->wait_all_children();
    $self->_copy_branch_to_current( $self->current );
    $self->remove_old_branches;

    if ( $self->is_multi_version ) {
        say "   - Writing versions TOC";
        $toc->write($dir);
        return {
            title => "$title [" . $self->branch_title( $self->current ) . "\\]",
            url   => $self->prefix . '/current/index.html',
            versions      => $self->prefix . '/index.html',
            section_title => $self->section_title()
        };
    }

    say "   - Writing redirect to current branch";
    write_html_redirect( $dir, "current/index.html" );

    return {
        title => $title,
        url   => $self->prefix . '/current/index.html'
    };
}

#===================================
sub _build_book {
#===================================
    my ( $self, $branch, $pm ) = @_;

    my $branch_dir    = $self->dir->subdir($branch);
    my $repo          = $self->repo;
    my $template      = $self->template;
    my $src_path      = $self->src_path;
    my $index         = $self->index;
    my $edit_url      = $repo->edit_url( $branch, $index );
    my $section_title = $self->section_title($branch);
    my $lang          = $self->lang;

    return
           if -e $branch_dir
        && !$template->md5_changed($branch_dir)
        && !$repo->has_changed( $src_path, $branch );

    my $checkout = $repo->local_clone($branch);
    $pm->start($branch) and return;
    say " - Branch: $branch - Building...";
    eval {
        if ( $self->single ) {
            $branch_dir->rmtree;
            $branch_dir->mkpath;
            build_single(
                $checkout->file($index),
                $branch_dir,
                version       => $branch,
                edit_url      => $edit_url,
                lang          => $lang,
                multi         => $self->is_multi_version,
                page_header   => $self->_page_header($branch),
                section_title => $section_title,
                toc           => $self->toc,
                template      => $template
            );
        }
        else {
            build_chunked(
                $checkout->file($index),
                $branch_dir,
                version       => $branch,
                edit_url      => $edit_url,
                lang          => $lang,
                chunk         => $self->chunk,
                multi         => $self->is_multi_version,
                page_header   => $self->_page_header($branch),
                section_title => $section_title,
                template      => $template
            );
            $self->_add_title_to_toc( $branch, $branch_dir );
        }
        $checkout->rmtree;
        say " - Branch: $branch - Finished";

        1;
    } && $pm->finish;

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
            $option .= '>' . $self->branch_title($_);
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

    say "   - Copying $branch to current";

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
sub _page_header {
#===================================
    my ( $self, $branch ) = @_;
    return '' unless $self->is_multi_version;

    my $current = $self->current;
    return '' if $current eq $branch;

    if ( $current !~ /-\w/ ) {
        $current .= '-zzzzzz';
    }
    if ( $branch !~ /-\w/ ) {
        $branch .= '-zzzzzz';
    }

    return $self->_page_header_text( $branch lt $current ? 'old' : 'new' );
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
sub section_title {
#===================================
    my $self   = shift;
    my $branch = shift || '';
    my $title  = $self->tags;
    return $title unless $self->is_multi_version;
    return $title . "/" . $branch;
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
sub branch_title     { shift->{branch_titles}->{ shift() } }
sub current          { shift->{current} }
sub is_multi_version { @{ shift->branches } > 1 }
sub tags             { shift->{tags} }
sub lang             { shift->{lang} }
#===================================

1;
