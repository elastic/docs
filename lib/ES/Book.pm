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
    zh_cn => {
        old => <<"HEADER",
你当前正在查看的是旧版本的文档。如果不是你要找的，请点击查看 <a href="../current/index.html">当前发布版本的文档</a>。
HEADER
        new => <<"HEADER"
你当前正在查看的是未发布版本的预览版文档。如果不是你要找的，请点击查看 <a href="../current/index.html">当前发布版本的文档</a>。
HEADER
    },
    ja => {
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
    ko => {
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

    my $temp_dir = $args{temp_dir}
        or die "No <temp_dir> specified for book <$title>";

    my $source = ES::Source->new(
        temp_dir => $temp_dir,
        sources  => $args{sources}
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

    my $subject = $args{subject}
        or die "No <subject> specified for book <$title>";

    my $lang = $args{lang} || 'en';

    # be careful about true/false here so there are no surprises.
    # otherwise someone is bound to set `asciidoctor` to `false`
    # and perl will evaluate that to true....
    my $asciidoctor = 0;
    if (exists $args{asciidoctor}) {
        $asciidoctor = $args{asciidoctor};
        if ($asciidoctor eq 'true') {
            $asciidoctor = 1;
        } elsif ($asciidoctor eq 'false') {
            $asciidoctor = 0;
        } else {
            die 'asciidoctor must be true or false but was ' . $asciidoctor;
        }
    }

    bless {
        title         => $title,
        dir           => $dir->subdir($prefix),
        template      => $template,
        source        => $source,
        prefix        => $prefix,
        chunk         => $chunk,
        toc           => $toc,
        single        => $args{single},
        index         => $index,
        branches      => \@branches,
        branch_titles => \%branch_titles,
        current       => $current,
        tags          => $tags,
        subject       => $subject,
        private       => $args{private} || '',
        noindex       => $args{noindex} || '',
        lang          => $lang,
        asciidoctor   => $asciidoctor,
    }, $class;
}

#===================================
sub build {
#===================================
    my ( $self, $rebuild ) = @_;

    my $toc = ES::Toc->new( $self->title );
    my $dir = $self->dir;
    $dir->mkpath;

    my $title = $self->title;

    my $pm = proc_man(
        $Opts->{procs},
        sub {
            my ( $pid, $error, $branch ) = @_;
            $self->source->mark_done( $title, $branch, $self->asciidoctor );
        }
    );

    my $rebuilding_any_branch = 0;
    my $rebuilding_current_branch = 0;
    for my $branch ( @{ $self->branches } ) {
        my $building = $self->_build_book( $branch, $pm, $rebuild );
        $rebuilding_any_branch ||= $building;

        my $branch_title = $self->branch_title($branch);
        if ( $branch eq $self->current ) {
            $toc->add_entry(
                {   title => "$title: $branch_title (current)",
                    url   => "current/index.html"
                }
            );
            $rebuilding_current_branch = $building;
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
    $self->_copy_branch_to_current( $self->current ) if $rebuilding_current_branch;
    $self->remove_old_branches;
    if ( $self->is_multi_version ) {
        if ( $rebuilding_any_branch ) {
            printf(" - %40.40s: Writing versions TOC\n", $self->title);
            $toc->write($dir);
        }
        return {
            title => "$title [" . $self->branch_title( $self->current ) . "\\]",
            url   => $self->prefix . '/current/index.html',
            versions      => $self->prefix . '/index.html',
            section_title => $self->section_title()
        };
    }
    if ( $rebuilding_any_branch ) {
        printf(" - %40.40s: Writing redirect to current branch...\n", $self->title);
        write_html_redirect( $dir, "current/index.html" );
    }
    return {
        title => $title,
        url   => $self->prefix . '/current/index.html'
    };
}

#===================================
sub _build_book {
#===================================
    my ( $self, $branch, $pm, $rebuild ) = @_;

    my $branch_dir    = $self->dir->subdir($branch);
    my $source        = $self->source;
    my $template      = $self->template;
    my $index         = $self->index;
    my $section_title = $self->section_title($branch);
    my $subject       = $self->subject;
    my $lang          = $self->lang;

    return 0
           if -e $branch_dir
        && !$rebuild
        && !$template->md5_changed($branch_dir)
        && !$source->has_changed( $self->title, $branch, $self->asciidoctor );

    my ( $checkout, $edit_urls, $first_path ) = $source->prepare($branch);

    $pm->start($branch) and return 1;
    printf(" - %40.40s: Building %s...\n", $self->title, $branch);
    eval {
        if ( $self->single ) {
            $branch_dir->rmtree;
            $branch_dir->mkpath;
            build_single(
                $first_path->file($index),
                $branch_dir,
                version       => $branch,
                lang          => $lang,
                edit_urls     => $edit_urls,
                root_dir      => $first_path,
                private       => $self->private,
                noindex       => $self->noindex,
                multi         => $self->is_multi_version,
                page_header   => $self->_page_header($branch),
                section_title => $section_title,
                subject       => $subject,
                toc           => $self->toc,
                template      => $template,
                resource      => [$checkout],
                asciidoctor   => $self->asciidoctor,
            );
        }
        else {
            build_chunked(
                $first_path->file($index),
                $branch_dir,
                version       => $branch,
                lang          => $lang,
                edit_urls     => $edit_urls,
                root_dir      => $first_path,
                private       => $self->private,
                noindex       => $self->noindex,
                chunk         => $self->chunk,
                multi         => $self->is_multi_version,
                page_header   => $self->_page_header($branch),
                section_title => $section_title,
                subject       => $subject,
                template      => $template,
                resource      => [$checkout],
                asciidoctor   => $self->asciidoctor,
            );
            $self->_add_title_to_toc( $branch, $branch_dir );
        }
        $checkout->rmtree;
        printf(" - %40.40s: Finished %s\n", $self->title, $branch);

        1;
    } && $pm->finish;

    my $error = $@;
    die "\nERROR building "
        . $self->title
        . " branch $branch\n\n"
        . $source->dump_recent_commits( $self->title, $branch )
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

    printf(" - %40.40s: Copying %s to current\n", $self->title, $branch);

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
        printf(" - %40.40s: Deleting old branch %s\n", $self->title, $version);
        $child->rmtree;
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
sub template         { shift->{template} }
sub prefix           { shift->{prefix} }
sub chunk            { shift->{chunk} }
sub toc              { shift->{toc} }
sub single           { shift->{single} }
sub index            { shift->{index} }
sub branches         { shift->{branches} }
sub branch_title     { shift->{branch_titles}->{ shift() } }
sub current          { shift->{current} }
sub is_multi_version { @{ shift->branches } > 1 }
sub private          { shift->{private} }
sub noindex          { shift->{noindex} }
sub tags             { shift->{tags} }
sub subject          { shift->{subject} }
sub source           { shift->{source} }
sub lang             { shift->{lang} }
sub asciidoctor      { shift->{asciidoctor} }
#===================================

1;
