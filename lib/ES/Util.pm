package ES::Util;

use strict;
use warnings;
use v5.10;

use File::Copy::Recursive qw(fcopy rcopy);
use Capture::Tiny qw(capture_merged tee_merged);
use Encode qw(decode_utf8);
use Path::Class qw(dir);

binmode( STDOUT, ':encoding(utf8)' );

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(
    run $Opts
    build_chunked build_single
    get_url
    sha_for
    timestamp
    write_html_redirect
);

our $Opts = {};

#===================================
sub build_chunked {
#===================================
    my ( $index, $dest, %opts ) = @_;

    my $chunk    = $opts{chunk} || 0;
    my $build    = $dest->parent;
    my $version  = $opts{version} || 'test build';
    my $multi    = $opts{multi} || 0;
    my $lenient  = $opts{lenient} || '';
    my $edit_url = $opts{edit_url} || '';

    my $output = run(
        'a2x', '-v',
        '--icons',
        '-d'              => 'book',
        '-f'              => 'chunked',
        '-a'              => 'showcomments=1',
        '--xsl-file'      => 'resources/website_chunked.xsl',
        '--asciidoc-opts' => '-fresources/es-asciidoc.conf',
        '--destination-dir=' . $build,
        ( $lenient ? '-L' : () ),
        docinfo($index),
        xsltopts(
            "toc.max.depth"            => 5,
            "toc.section.depth"        => $chunk,
            "chunk.section.depth"      => $chunk,
            "local.book.version"       => $version,
            "local.book.multi_version" => $multi,
            "local.root_dir"           => $index->dir->absolute,
            "local.edit_url"           => $edit_url
        ),
        $index
    );

    my @warn = grep {/(WARNING|ERROR)/} split "\n", $output;
    if (@warn) {
        $lenient
            ? warn join "\n", @warn
            : die join "\n", @warn;
    }

    my ($chunk_dir) = grep { -d and /\.chunked$/ } $build->children
        or die "Couldn't find chunk dir in <$build>";

    finish_build( $index->parent, $chunk_dir );
    extract_toc_from_index($chunk_dir);
    $dest->rmtree;
    rename $chunk_dir, $dest
        or die "Couldn't move <$chunk_dir> to <$dest>: $!";
}

#===================================
sub build_single {
#===================================
    my ( $index, $dest, %opts ) = @_;

    my $type = $opts{type} || 'book';
    my $toc = $opts{toc} ? "$type toc" : '';
    my $lenient  = $opts{lenient}  || '';
    my $version  = $opts{version}  || 'test build';
    my $multi    = $opts{multi}    || 0;
    my $edit_url = $opts{edit_url} || '';
    my $comments = $opts{comments} || 0;

    my $output = run(
        'a2x', '-v',
        '--icons',
        '-f'              => 'xhtml',
        '-d'              => $type,
        '-a'              => 'showcomments=1',
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

    finish_build( $index->parent, $dest );

}

#===================================
sub finish_build {
#===================================
    my ( $source, $dest ) = @_;

    # Apply template to HTML files
    $Opts->{template}->apply($dest);

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
    my ( $out, $ok );
    if ( $Opts->{verbose} ) {
        say "Running: @args";
        ( $out, $ok ) = tee_merged { system(@args) == 0 };
    }
    else {
        ( $out, $ok ) = capture_merged { system(@args) == 0 };
    }

    die "Error executing: @args\n$out"
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
    eval { $res = run( @cmd, $url ); } && return $res;

    die "URL ($url) failed with $@\n";
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

1
