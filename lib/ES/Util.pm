package ES::Util;

use strict;
use warnings;
use v5.10;

use File::Copy::Recursive qw(fcopy rcopy);
use Capture::Tiny qw(capture tee);
use Encode qw(decode_utf8);
use Path::Class qw(dir);
use Parallel::ForkManager();

binmode( STDOUT, ':encoding(utf8)' );

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(
    run $Opts
    build_chunked build_single build_pdf
    proc_man
    get_url
    git_creds
    sha_for
    timestamp
    write_html_redirect
);

our $Opts = { procs => 3, lang => 'en' };

#===================================
sub build_chunked {
#===================================
    my ( $index, $dest, %opts ) = @_;

    my $chunk    = $opts{chunk}         || 0;
    my $version  = $opts{version}       || 'test build';
    my $multi    = $opts{multi}         || 0;
    my $lenient  = $opts{lenient}       || '';
    my $edit_url = $opts{edit_url}      || '';
    my $lang     = $opts{lang}          || 'en';
    my $section  = $opts{section_title} || '';
    my $page_header = custom_header($index) || $opts{page_header} || '';
    $dest->rmtree;
    $dest->mkpath;
    my $output = run(
        'a2x', '-v',
        '--icons',
        '-d'              => 'book',
        '-f'              => 'chunked',
        '-a'              => 'showcomments=1',
        '-a'              => "lang=$lang",
        '--xsl-file'      => 'resources/website_chunked.xsl',
        '--asciidoc-opts' => '-fresources/es-asciidoc.conf',
        '--destination-dir=' . $dest,
        ( $lenient ? '-L' : () ),
        docinfo($index),
        xsltopts(
            "toc.max.depth"            => 5,
            "toc.section.depth"        => $chunk,
            "chunk.section.depth"      => $chunk,
            "local.book.version"       => $version,
            "local.book.multi_version" => $multi,
            "local.page.header"        => $page_header,
            "local.book.section.title" => "Docs/$section",
            "local.root_dir"           => $index->dir->absolute,
            "local.edit_url"           => $edit_url,
            "l10n.gentext.language"    => 'en'
        ),
        $index
    );

    my @warn = grep {/(WARNING|ERROR)/} split "\n", $output;
    if (@warn) {
        $lenient
            ? warn join "\n", @warn
            : die join "\n", @warn;
    }

    my ($chunk_dir) = grep { -d and /\.chunked$/ } $dest->children
        or die "Couldn't find chunk dir in <$dest>";

    finish_build( $index->parent, $chunk_dir, $lang );
    extract_toc_from_index($chunk_dir);
    for ( $chunk_dir->children ) {
        run( 'mv', $_, $dest );
    }
    $chunk_dir->rmtree;
}

#===================================
sub build_single {
#===================================
    my ( $index, $dest, %opts ) = @_;

    my $type = $opts{type} || 'book';
    my $toc = $opts{toc} ? "$type toc" : '';
    my $lenient  = $opts{lenient}       || '';
    my $version  = $opts{version}       || 'test build';
    my $multi    = $opts{multi}         || 0;
    my $edit_url = $opts{edit_url}      || '';
    my $lang     = $opts{lang}          || 'en';
    my $comments = $opts{comments}      || 0;
    my $section  = $opts{section_title} || '';
    my $page_header = custom_header($index) || $opts{page_header} || '';

    my $output = run(
        'a2x', '-v',
        '--icons',
        '-f'              => 'xhtml',
        '-d'              => $type,
        '-a'              => 'showcomments=1',
        '-a'              => "lang=$lang",
        '--xsl-file'      => 'resources/website.xsl',
        '--asciidoc-opts' => '-fresources/es-asciidoc.conf',
        '--destination-dir=' . $dest,
        ( $lenient ? '-L' : () ),
        docinfo($index),
        xsltopts(
            "generate.toc"             => $toc,
            "toc.section.depth"        => 0,
            "local.book.version"       => $version,
            "local.book.multi_version" => $multi,
            "local.page.header"        => $page_header,
            "local.book.section.title" => "Docs/$section",
            "local.root_dir"           => $index->dir->absolute,
            "local.edit_url"           => $edit_url,
            "local.comments"           => $comments,
        ),
        $index
    );

    my @warn = grep {/(WARNING|ERROR)/} split "\n", $output;
    if (@warn) {
        $lenient
            ? warn join "\n", @warn
            : die join "\n", @warn;
    }

    my $base_name = $index->basename;
    $base_name =~ s/\.[^.]+$/.html/;

    if ( $base_name ne 'index.html' ) {
        my $src = $dest->file($base_name);
        rename $src, $dest->file('index.html')
            or die "Couldn't rename <$src> to <index.html>: $!";
    }

    finish_build( $index->parent, $dest, $lang );

}

#===================================
sub build_pdf {
#===================================
    my ( $index, $dest, %opts ) = @_;

    my $version   = $opts{version}   || 'test build';
    my $lenient   = $opts{lenient}   || '';
    my $toc_level = $opts{toc_level} || 7;
    my $lang      = $opts{lang}      || 'en';

    my $output = run(
        'a2x', '-v',
        '-a' => "lang=$lang",
        '--icons',
        '-d' => 'book',
        '-f' => 'pdf',
        '--fop',
        '--icons-dir=./resources/asciidoc-8.6.8/images/icons/',
        '--xsl-file'      => 'resources/fo.xsl',
        '--asciidoc-opts' => '-fresources/es-asciidoc.conf',
        '--destination-dir=' . $dest,
        ( $lenient ? '-L' : () ),
        docinfo($index),
        xsltopts(
            "img.src.path"       => $index->parent->absolute . '/',
            "toc.max.depth"      => $toc_level,
            "local.book.version" => $version,
            "local.root_dir"     => $index->dir->absolute,
        ),
        $index
    );

    my @output = split "\n", $output;
    my @error = grep {/SEVERE|ERROR/} @output;
    if ( @error && !$lenient ) {
        die join "\n", @error;
    }
    else {
        my @warn = grep {/WARNING|SEVERE|ERROR/} @output;
        warn join "\n", @warn;
    }
}

#===================================
sub finish_build {
#===================================
    my ( $source, $dest, $lang ) = @_;

    # Apply template to HTML files
    $Opts->{template}->apply( $dest, $lang );

    my $snippets_dest = $dest->subdir('snippets');
    my $snippets_src;

    # If lenient, look for snippets in parent directories
    my $levels = $Opts->{lenient} ? 5 : 1;
    while ( $levels-- ) {
        $snippets_src = $source->subdir('snippets');
        last if -e $snippets_src;
        $source = $source->parent;
    }

    # Copy custom sense snippets to dest
    if ( -e $snippets_src ) {
        rcopy( $snippets_src, $snippets_dest )
            or die "Couldn't copy <$snippets_src> to <$snippets_dest>: $!";
    }
}

#===================================
sub extract_toc_from_index {
#===================================
    my $dir = shift;
    my $html
        = $dir->file('index.html')->slurp( 'iomode' => '<:encoding(UTF-8)' );
    $html =~ s/^.+<!--START_TOC-->//s;
    $html =~ s/<!--END_TOC-->.*$//s;
    $dir->file('toc.html')->spew( iomode => '>:utf8', $html );
}

#===================================
sub docinfo {
#===================================
    my $index = shift;
    my $name  = $index->basename;
    $name =~ s/\.[^.]+$//;
    my $docinfo = $index->dir->file("$name-docinfo.xml");
    return -e $docinfo ? ( -a => 'docinfo' ) : ();
}

#===================================
sub custom_header {
#===================================
    my $index  = shift;
    my $custom = $index->dir->file('page_header.html');
    return unless -e $custom;
    return scalar $custom->slurp( iomode => '<:encoding(UTF-8)' );
}

#===================================
sub xsltopts {
#===================================
    my @opts;
    while (@_) {
        my $key = shift;
        my $val = shift;
        push @opts, '--xsltproc-opts', "--stringparam $key '$val'";
    }
    return @opts;
}

#===================================
sub write_html_redirect {
#===================================
    my ( $dir, $url ) = @_;
    my $html = <<"HTML";
<html>
  <head>
    <meta http-equiv="refresh" content="0; url=$url">
    <meta name="robots" content="noindex">
  </head>
  <body>
    Redirecting to <a href="$url">$url</a>.
  </body>
</html>
HTML

    $dir->file('index.html')->spew( iomode => '>:utf8', $html );

}
#===================================
sub run (@) {
#===================================
    my @args = @_;
    my ( $out, $err, $ok );

    if ( $Opts->{verbose} ) {
        say "Running: @args";
        ( $out, $err, $ok ) = tee { system(@args) == 0 };
    }
    else {
        ( $out, $err, $ok ) = capture { system(@args) == 0 };
    }

    die "Error executing: @args\n$out\n---\n$err"
        unless $ok;

    return $out;
}

#===================================
sub get_url {
#===================================
    my ( $url, $cred ) = @_;

    my @cmd = qw(curl -s -S -f -A http://search.elastic.co);
    push @cmd, ( '--user', $cred ) if $cred;

    my $res;
    eval { $res = run( @cmd, $url ); die $res if $res =~ /^Moved/; 1 }
        && return $res;

    die "URL ($url) failed with $@\n";
}

#===================================
sub proc_man {
#===================================
    my ( $procs, $finish ) = @_;
    my $pm = Parallel::ForkManager->new($procs);
    $pm->set_waitpid_blocking_sleep(0.1);
    $pm->run_on_finish(
        sub {
            if ( $_[1] ) {
                kill -9, $pm->running_procs();
                kill 9,  $pm->running_procs();
                exit $_[1];
            }
            $finish->(@_) if $finish;
        }
    );
    return $pm;

}

#===================================
sub sha_for {
#===================================
    my $rev = shift;
    my $sha = eval { run 'git', 'rev-parse', $rev } || '';
    chomp $sha;
    return $sha;
}

#===================================
sub timestamp {
#===================================
    my ( $sec, $min, $hour, $mday, $mon, $year )
        = gmtime( @_ ? shift() : time() );
    $year += 1900;
    $mon++;
    sprintf "%04d-%02d-%02dT%02d:%02d:%02d+00:00", $year, $mon, $mday, $hour,
        $min, $sec;
}

#===================================
sub git_creds {
#===================================
    my ( $action, $body ) = @_;

    require IPC::Open3;

    my ( $chld_out, $chld_in, $pid );
    no warnings 'once';
    open( NULL, ">", File::Spec->devnull );
    $pid = IPC::Open3::open3( $chld_in, $chld_out, ">&NULL", 'git',
        'credential', $action );

    print $chld_in "$body\n\n";

    waitpid( $pid, 0 );
    my $out = join "", <$chld_out>;
    return $out || '';

}

1
