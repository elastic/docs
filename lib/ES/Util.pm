package ES::Util;

use strict;
use warnings;
use v5.10;

use File::Copy::Recursive qw(fcopy rcopy);
use Capture::Tiny qw(capture tee);
use Encode qw(decode_utf8);
use Path::Class qw(dir file);
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

    my $chunk     = $opts{chunk}         || 0;
    my $version   = $opts{version}       || '';
    my $multi     = $opts{multi}         || 0;
    my $lenient   = $opts{lenient}       || '';
    my $lang      = $opts{lang}          || 'en';
    my $edit_url  = $opts{edit_url}      || '';
    my $root_dir  = $opts{root_dir}      || '';
    my $section   = $opts{section_title} || '';
    my $subject   = $opts{subject}       || '';
    my $private   = $opts{private}       || '';
    my $resources = $opts{resource}      || [];
    my $noindex   = $opts{noindex}       || '';
    my $page_header = custom_header($index) || $opts{page_header} || '';
    my $asciidoctor = $opts{asciidoctor} || 0;

    $dest->rmtree;
    $dest->mkpath;

    my %xsltopts = (
            "toc.max.depth"            => 5,
            "toc.section.depth"        => $chunk,
            "chunk.section.depth"      => $chunk,
            "local.book.version"       => $version,
            "local.book.multi_version" => $multi,
            "local.page.header"        => $page_header,
            "local.book.section.title" => "Learn/Docs/$section",
            "local.book.subject"       => $subject,
            "local.noindex"            => $noindex,
    );

    my ( $output, $died );
    if ( $asciidoctor ) {
        %xsltopts = (%xsltopts,
                'callout.graphics' => 1,
                'navig.graphics'   => 1,
                'admon.textlabel'  => 0,
                'admon.graphics'   => 1,
        );
        my $chunks_path = dir("$dest/.chunked");
        $chunks_path->mkpath;
        # Emulate asciidoc_dir because we use it to find shared asciidoc files
        # but asciidoctor doesn't support it.
        my $asciidoc_dir = dir('resources/asciidoc-8.6.8/')->absolute;
        eval {
            $output = run(
                'asciidoctor', '-v', '--trace',
                '-r' => dir('resources/asciidoctor/lib/extensions.rb')->absolute,
                # TODO figure out resource
                # ( map { ( '--resource' => $_ ) } @$resources ),
                '-b' => 'docbook45',
                '-d' => 'book',
                '-a' => 'showcomments=1',
                '-a' => "lang=$lang",
                '-a' => 'repo_root=' . $root_dir,
                # Use ` to delimit monospaced literals because our docs
                # expect that
                '-a' => 'compat-mode=legacy',
                $private ? () : ( '-a' => "edit_url=$edit_url" ),
                # Disable warning on missing attributes because we have
                # missing attributes!
                # '-a' => 'attribute-missing=warn',
                '-a' => 'asciidoc-dir=' . $asciidoc_dir,
                '--destination-dir=' . $dest,
                docinfo($index),
                $index
            );
            if ( !$lenient ) {
                $output .= _xml_lint($dest);
            }
            $output .= run(
                'xsltproc',
                rawxsltopts(%xsltopts),
                '--stringparam', 'base.dir', $chunks_path->absolute . '/',
                file('resources/website_chunked.xsl')->absolute,
                "$dest/index.xml"
            );
            # TODO copy_resources?
            unlink "$dest/index.xml";
            1;
        } or do { $output = $@; $died = 1; };
    }
    else {
        eval {
            $output = run(
                'a2x', '-v',    #'--keep',
                '--icons',
                ( map { ( '--resource' => $_ ) } @$resources ),
                '-d' => 'book',
                '-f' => 'chunked',
                '-a' => 'showcomments=1',
                '-a' => "lang=$lang",
                '-a' => 'base_edit_url=' . $edit_url,
                '-a' => 'root_dir=' . $root_dir,
                # Use ` to delimit monospaced literals because our docs
                # expect that
                '-a' => 'compat-mode=legacy',
                $private ? ( '-a' => 'edit_url!' ) : (),
                '--xsl-file'      => 'resources/website_chunked.xsl',
                '--asciidoc-opts' => '-fresources/es-asciidoc.conf',
                '--destination-dir=' . $dest,
                ( $lenient ? '-L' : () ),
                docinfo($index),
                xsltopts(%xsltopts),
                $index
            );
            1;
        } or do { $output = $@; $died = 1; };
    }

    _check_build_error( $output, $died, $lenient );

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
    my $lenient   = $opts{lenient}       || '';
    my $version   = $opts{version}       || '';
    my $multi     = $opts{multi}         || 0;
    my $lang      = $opts{lang}          || 'en';
    my $edit_url  = $opts{edit_url}      || '';
    my $root_dir  = $opts{root_dir}      || '';
    my $section   = $opts{section_title} || '';
    my $subject   = $opts{subject}       || '';
    my $private   = $opts{private}       || '';
    my $noindex   = $opts{noindex}       || '';
    my $resources = $opts{resource}      || [];
    my $page_header = custom_header($index) || $opts{page_header} || '';
    my $asciidoctor = $opts{asciidoctor} || 0;

    my %xsltopts = (
            "generate.toc"             => $toc,
            "toc.section.depth"        => 0,
            "local.book.version"       => $version,
            "local.book.multi_version" => $multi,
            "local.page.header"        => $page_header,
            "local.book.section.title" => "Learn/Docs/$section",
            "local.book.subject"       => $subject,
            "local.noindex"            => $noindex,
    );

    my ( $output, $died );
    if ( $asciidoctor ) {
        %xsltopts = (%xsltopts,
                'callout.graphics' => 1,
                'navig.graphics'   => 1,
                'admon.textlabel'  => 0,
                'admon.graphics'   => 1,
        );
        if ( $type eq 'book' ) {
            $xsltopts{'chunk.section.depth'} = 0;
        }
        # Emulate asciidoc_dir because we use it to find shared asciidoc files
        # but asciidoctor doesn't support it.
        my $asciidoc_dir = dir('resources/asciidoc-8.6.8/')->absolute;

        eval {
            $output = run(
                'asciidoctor', '-v', '--trace',
                '-r' => dir('resources/asciidoctor/lib/extensions.rb')->absolute,
                # TODO figure out resource
                # ( map { ( '--resource' => $_ ) } @$resources ),
                '-b' => 'docbook45',
                '-d' => $type,
                '-a' => 'showcomments=1',
                '-a' => "lang=$lang",
                '-a' => 'repo_root=' . $root_dir,
                $private ? () : ( '-a' => "edit_url=$edit_url" ),
                '-a' => 'asciidoc-dir=' . $asciidoc_dir,
                # Disable warning on missing attributes because we have
                # missing attributes!
                # '-a' => 'attribute-missing=warn',
                '--destination-dir=' . $dest,
                docinfo($index),
                $index
            );
            if ( !$lenient ) {
                $output .= _xml_lint($dest);
            }
            $output .= run(
                'xsltproc',
                rawxsltopts(%xsltopts),
                '--output' => "$dest/index.html",
                file('resources/website.xsl')->absolute,
                "$dest/index.xml"
            );
            # TODO copy_resources?
            unlink "$dest/index.xml";
            1;
        } or do { $output = $@; $died = 1; };
    }
    else {
        eval {
            $output = run(
                'a2x', '-v',
                '--icons',
                ( map { ( '--resource' => $_ ) } @$resources ),
                '-f' => 'xhtml',
                '-d' => $type,
                '-a' => 'showcomments=1',
                '-a' => "lang=$lang",
                '-a' => 'base_edit_url=' . $edit_url,
                '-a' => 'root_dir=' . $root_dir,
                $private ? ( '-a' => 'edit_url!' ) : (),
                '--xsl-file'      => 'resources/website.xsl',
                '--asciidoc-opts' => '-fresources/es-asciidoc.conf',
                '--destination-dir=' . $dest,
                ( $lenient ? '-L' : () ),
                docinfo($index),
                xsltopts(%xsltopts),
                $index
            );
            1;
        } or do { $output = $@; $died = 1; };
    }

    _check_build_error( $output, $died, $lenient );

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
sub _check_build_error {
#===================================
    my ( $output, $died, $lenient ) = @_;
    my $warned = grep {/^(a2x|asciidoc(tor)?): (WARNING):/} split "\n", $output;

    return unless $died || $warned;

    my @warn = grep { /(WARNING|ERROR):/ || !/^(a2x|asciidoc(tor)?): / } split "\n",
        $output;

    if ( $died || $warned && !$lenient ) {
        die join "\n", ( '', @warn, '' );
    }
    warn join "\n", ( '', @warn, '' );
}

#===================================
# Forks xmllint externally and may call `die`. Call inside of an `eval` block
# to be safe and handle errors.
sub _xml_lint {
#===================================
    my ( $dest ) = @_;
    return run(
            'xmllint',
            '--nonet',
            '--noout',
            '--valid',
            "$dest/index.xml"
    );
}

#===================================
sub build_pdf {
#===================================
    my ( $index, $dest, %opts ) = @_;

    my $version   = $opts{version}   || '';
    my $lenient   = $opts{lenient}   || '';
    my $toc_level = $opts{toc_level} || 7;
    my $lang      = $opts{lang}      || 'en';
    my $resources = $opts{resource}  || [];

    my $output = run(
        'a2x', '-v',
        '-a' => "lang=$lang",
        '--icons',
        ( map { ( '--resource' => $_ ) } @$resources ),
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
sub rawxsltopts {
#===================================
    my @opts;
    while (@_) {
        my $key = shift;
        my $val = shift;
        push @opts, '--stringparam', $key, "$val";
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
        say 'Running: ' . join(' ', map { "\"$_\"" } @args);
        ( $out, $err, $ok ) = tee { system(@args) == 0 };
    }
    else {
        ( $out, $err, $ok ) = capture { system(@args) == 0 };
    }

    my $combined = "$out\n$err";
    $combined =~ s/^\s+|\s+$//g;
    return $combined if $ok;

    my $git_dir = $ENV{GIT_DIR} ? "in GIT_DIR $ENV{GIT_DIR}" : "";
    die "Error executing: @args $git_dir\n$out\n---\n$err"
        unless $ok;

    return $combined;
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
                die "Child exited with $_[1]";
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
