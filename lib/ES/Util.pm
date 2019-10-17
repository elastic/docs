package ES::Util;

use strict;
use warnings;
use v5.10;

use File::Copy::Recursive qw(rcopy rmove);
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
    timestamp
    write_html_redirect
    write_nginx_redirects
    write_nginx_test_config
    write_nginx_preview_config
    start_web_resources_watcher
    start_preview
    build_web_resources
);

our $Opts = { procs => 3, lang => 'en' };

#===================================
sub build_chunked {
#===================================
    my ( $index, $raw_dest, $dest, %opts ) = @_;

    my $chunk     = $opts{chunk}         || 0;
    my $version   = $opts{version}       || '';
    my $multi     = $opts{multi}         || 0;
    my $lenient   = $opts{lenient}       || '';
    my $lang      = $opts{lang}          || 'en';
    my $edit_urls = $opts{edit_urls};
    my $root_dir  = $opts{root_dir};
    my $section   = $opts{section_title} || '';
    my $subject   = $opts{subject}       || '';
    my $private   = $opts{private}       || '';
    my $resources = $opts{resource}      || [];
    my $noindex   = $opts{noindex}       || '';
    my $page_header = custom_header($index) || $opts{page_header} || '';
    my $asciidoctor = $opts{asciidoctor} || 0;
    my $latest    = $opts{latest};
    my $respect_edit_url_overrides = $opts{respect_edit_url_overrides} || '';
    my $alternatives = $opts{alternatives} || [];
    my $alternatives_summary = $raw_dest->file('alternatives_summary.json');
    my $branch = $opts{branch};
    my $roots = $opts{roots};

    die "Can't find index [$index]" unless -f $index;

    $dest->rmtree;
    $dest->mkpath;
    $raw_dest->rmtree;
    $raw_dest->mkpath;

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
        my $dest_xml = $index->basename;
        $dest_xml =~ s/\.a(scii)?doc$/\.xml/;
        $dest_xml = $raw_dest->file($dest_xml);

        %xsltopts = (%xsltopts,
                'navig.graphics'   => 1,
                'admon.textlabel'  => 0,
                'admon.graphics'   => 1,
        );
        my $chunks_path = dir("$raw_dest/.chunked");
        $chunks_path->mkpath;
        # Emulate asciidoc_dir because we use it to find shared asciidoc files
        # but asciidoctor doesn't support it.
        my $asciidoc_dir = dir('resources/asciidoc-8.6.8/')->absolute;
        # We use the admonishment images from asciidoc so add it as a resource
        # so we can find them
        push @$resources, $asciidoc_dir;
        eval {
            $output = run(
                'asciidoctor', '-v', '--trace',
                '-r' => dir('resources/asciidoctor/lib/extensions.rb')->absolute,
                '-b' => 'docbook45',
                '-d' => 'book',
                '-a' => 'showcomments=1',
                '-a' => "lang=$lang",
                '-a' => "source_branch=$branch",
                # Use ` to delimit monospaced literals because our docs
                # expect that
                '-a' => 'compat-mode=legacy',
                $private || !$edit_urls ? () : ( '-a' => "edit_urls=" .
                    edit_urls_for_asciidoctor($edit_urls) ),
                # Disable warning on missing attributes because we have
                # missing attributes!
                # '-a' => 'attribute-missing=warn',
                '-a' => 'asciidoc-dir=' . $asciidoc_dir,
                '-a' => 'resources=' . join(',', @$resources),
                '-a' => 'copy-admonition-images=png',
                $latest ? () : ('-a' => "migration-warnings=false"),
                $respect_edit_url_overrides ? ('-a' => "respect_edit_url_overrides=true") : (),
                @{ $alternatives } ? (
                    '-a' => _format_alternatives($alternatives),
                    '-a' => "alternative_language_report=$raw_dest/alternatives_report.json",
                    '-a' => "alternative_language_summary=$alternatives_summary",
                ) : (),
                '-a' => 'relativize-link=https://www.elastic.co/',
                roots_opts( $roots ),
                '--destination-dir=' . $raw_dest,
                docinfo($index),
                $index
            );
            1;
        } or do { $output = $@; $died = 1; };
        _check_build_error( $output, $died, $lenient );

        if ( !$lenient ) {
            eval {
                $output = _xml_lint($dest_xml);
                1;
            } or do { $output = $@; $died = 1; };
            _check_build_error( $output, $died, $lenient );
        }
        eval {
            $output = run(
                'xsltproc',
                rawxsltopts(%xsltopts),
                '--stringparam', 'base.dir', $chunks_path->absolute . '/',
                file('resources/website_chunked.xsl')->absolute,
                $dest_xml
            );
            1;
        } or do { $output = $@; $died = 1; };
        _check_build_error( $output, $died, $lenient );
        unlink $dest_xml;
    }
    else {
        my $edit_url = $edit_urls->{$root_dir};
        eval {
            $output = run(
                'a2x', '-v',    #'--keep',
                '--icons',
                ( map { ( '--resource' => $_ ) } @$resources ),
                '-d' => 'book',
                '-f' => 'chunked',
                '-a' => 'showcomments=1',
                '-a' => "lang=$lang",
                '-a' => "source_branch=$branch",
                '-a' => 'base_edit_url=' . $edit_url,
                '-a' => 'root_dir=' . $root_dir,
                # Use ` to delimit monospaced literals because our docs
                # expect that
                '-a' => 'compat-mode=legacy',
                $private ? ( '-a' => 'edit_url!' ) : (),
                roots_opts( $roots ),
                '--xsl-file'      => 'resources/website_chunked.xsl',
                '--asciidoc-opts' => '-fresources/es-asciidoc.conf',
                '--destination-dir=' . $raw_dest,
                ( $lenient ? '-L' : () ),
                docinfo($index),
                xsltopts(%xsltopts),
                $index
            );
            1;
        } or do { $output = $@; $died = 1; };
        _check_build_error( $output, $died, $lenient );
    }

    my ($chunk_dir) = grep { -d and /\.chunked$/ } $raw_dest->children
        or die "Couldn't find chunk dir in <$raw_dest>";

    for ( $chunk_dir->children ) {
        my $child_dest = $raw_dest->file( $_->relative( $chunk_dir ) );
        if ( $_->basename !~ /\.html$/ ) {
            rmove( $_, $child_dest );
            next;
        }
        # Convert docbook's ceremonial output into html5
        my $contents = $_->slurp( iomode => '<:encoding(UTF-8)' );
        $contents = _html5ify( $contents );
        $contents = _extract_autosense_snippets( $_, $raw_dest, $contents ) unless $asciidoctor;
        $child_dest->spew( iomode => '>:utf8', $contents );
        unlink $_ or die "Coudln't remove $_ $!";
    }
    extract_toc_from_index( $raw_dest );
    finish_build( $index->parent, $raw_dest, $dest, $lang, 0 );
    $chunk_dir->rmtree;
}

#===================================
sub build_single {
#===================================
    my ( $index, $raw_dest, $dest, %opts ) = @_;

    my $type = $opts{type} || 'book';
    my $toc = $opts{toc} ? "$type toc" : '';
    my $lenient   = $opts{lenient}       || '';
    my $version   = $opts{version}       || '';
    my $multi     = $opts{multi}         || 0;
    my $lang      = $opts{lang}          || 'en';
    my $edit_urls = $opts{edit_urls};
    my $root_dir  = $opts{root_dir};
    my $section   = $opts{section_title} || '';
    my $subject   = $opts{subject}       || '';
    my $private   = $opts{private}       || '';
    my $noindex   = $opts{noindex}       || '';
    my $resources = $opts{resource}      || [];
    my $page_header = custom_header($index) || $opts{page_header} || '';
    my $asciidoctor = $opts{asciidoctor} || 0;
    my $latest    = $opts{latest};
    my $respect_edit_url_overrides = $opts{respect_edit_url_overrides} || '';
    my $alternatives = $opts{alternatives} || [];
    my $alternatives_summary = $raw_dest->file('alternatives_summary.json');
    my $branch = $opts{branch};
    my $roots = $opts{roots};

    die "Can't find index [$index]" unless -f $index;

    unless ( $opts{is_toc} ) {
        # Usually books live in their own directory so we can just `rm -rf`
        # those directories and start over. But the Table of Contents for all
        # vrsions of a book is written to the directory that contains all of
        # the versions of that book. `rm -rf`ed there we'd lose all of the
        # versions of the book. So we just don't.
        $dest->rmtree;
        $dest->mkpath;
        $raw_dest->rmtree;
        $raw_dest->mkpath;
    }

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
        my $dest_xml = $index->basename;
        $dest_xml =~ s/\.a(scii)?doc$/\.xml/;
        $dest_xml = $raw_dest->file($dest_xml);

        %xsltopts = (%xsltopts,
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
        # We use the admonishment images from asciidoc so add it as a resource
        # so we can find them
        push @$resources, $asciidoc_dir;
        eval {
            $output = run(
                'asciidoctor', '-v', '--trace',
                '-r' => dir('resources/asciidoctor/lib/extensions.rb')->absolute,
                '-b' => 'docbook45',
                '-d' => $type,
                '-a' => 'showcomments=1',
                '-a' => "lang=$lang",
                '-a' => "source_branch=$branch",
                $private || !$edit_urls ? () : ( '-a' => "edit_urls=" .
                    edit_urls_for_asciidoctor($edit_urls) ),
                '-a' => 'asciidoc-dir=' . $asciidoc_dir,
                '-a' => 'resources=' . join(',', @$resources),
                '-a' => 'copy-admonition-images=png',
                $latest ? () : ('-a' => "migration-warnings=false"),
                $respect_edit_url_overrides ? ('-a' => "respect_edit_url_overrides=true") : (),
                @{ $alternatives } ? (
                    '-a' => _format_alternatives($alternatives),
                    '-a' => "alternative_language_report=$raw_dest/alternatives_report.json",
                    '-a' => "alternative_language_summary=$alternatives_summary",
                ) : (),
                # Disable warning on missing attributes because we have
                # missing attributes!
                # '-a' => 'attribute-missing=warn',
                '-a' => 'relativize-link=https://www.elastic.co/',
                roots_opts( $roots ),
                '--destination-dir=' . $raw_dest,
                docinfo($index),
                $index
            );
            1;
        } or do { $output = $@; $died = 1; };
        _check_build_error( $output, $died, $lenient );

        if ( !$lenient ) {
            eval {
                $output = _xml_lint($dest_xml);
                1;
            } or do { $output = $@; $died = 1; };
            _check_build_error( $output, $died, $lenient );
        }
        eval {
            $output = run(
                'xsltproc',
                rawxsltopts(%xsltopts),
                '--output' => "$raw_dest/index.html",
                file('resources/website.xsl')->absolute,
                $dest_xml
            );
            1;
        } or do { $output = $@; $died = 1; };
        _check_build_error( $output, $died, $lenient );
        unlink $dest_xml;
    }
    else {
        my $edit_url = $edit_urls->{$root_dir};
        eval {
            $output = run(
                'a2x', '-v',
                '--icons',
                ( map { ( '--resource' => $_ ) } @$resources ),
                '-f' => 'xhtml',
                '-d' => $type,
                '-a' => 'showcomments=1',
                '-a' => "lang=$lang",
                '-a' => "source_branch=$branch",
                '-a' => 'base_edit_url=' . $edit_url,
                '-a' => 'root_dir=' . $root_dir,
                $private ? ( '-a' => 'edit_url!' ) : (),
                roots_opts( $roots ),
                '--xsl-file'      => 'resources/website.xsl',
                '--asciidoc-opts' => '-fresources/es-asciidoc.conf',
                '--destination-dir=' . $raw_dest,
                ( $lenient ? '-L' : () ),
                docinfo($index),
                xsltopts(%xsltopts),
                $index
            );
            1;
        } or do { $output = $@; $died = 1; };
        _check_build_error( $output, $died, $lenient );
    }

    my $base_name = $index->basename;
    $base_name =~ s/\.[^.]+$/.html/;

    my $html_file = $raw_dest->file('index.html');
    if ( $base_name ne 'index.html' ) {
        my $src = $raw_dest->file($base_name);
        rename $src, $html_file
            or die "Couldn't rename <$src> to <index.html>: $!";
    }

    my $contents = $html_file->slurp( iomode => '<:encoding(UTF-8)' );
    $contents = _html5ify( $contents );
    $contents = _extract_autosense_snippets( $html_file, $raw_dest, $contents ) unless $asciidoctor;
    $html_file->spew( iomode => '>:utf8', $contents );

    finish_build( $index->parent, $raw_dest, $dest, $lang, $opts{is_toc} );
}

#===================================
sub _check_build_error {
#===================================
    my ( $output, $died, $lenient ) = @_;

    my @lines = split "\n", $output;
    my @build_warnings = grep {/^(a2x|asciidoc(tor)?): (WARNING|ERROR):/} @lines;
    my $warned = @build_warnings;
    return unless $died || $warned;

    my @warn = grep { /(WARNING|ERROR):/ || !/^(a2x|asciidoc(tor)?): / } @lines;

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
    my ( $dest_xml ) = @_;
    return run(
            'xmllint',
            '--nonet',
            '--noout',
            '--valid',
            "$dest_xml"
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
    die "Error executing: @args $git_dir\n---out---\n$out\n---err---\n$err\n---------\n"
        unless $ok;

    return $combined;
}

#===================================
sub finish_build {
#===================================
    my ( $source, $raw_dest, $dest, $lang, $is_toc ) = @_;

    # Write a file with the book's language into the raw directory so the
    # templating can apply it now *and* on the fly later
    $raw_dest->file('lang')->spew( iomode => '>:utf8', "$lang\n" );


    # Apply template to HTML files
    run 'node', 'template/cli.js', '--template', 'resources/web/template.html',
        '--source', $raw_dest, '--dest', $dest,
        $is_toc ? ('--tocmode') : ();

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
sub roots_opts {
#===================================
    my $roots = shift;
    my @result;

    for ( keys %$roots ) {
        push @result, ( '-a', $_ . '-root=' . $$roots{ $_ } );
    }
    return @result;
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
# Convert docbook's xhtml output into html5. In a perfect world the docs build
# process would generate perfect output but for now it doesn't so we bring perl
# to the rescue here!
#===================================
sub _html5ify {
#===================================
    my ( $contents ) = @_;

    # Strip the xml prolog
    $contents =~ s/^<\?xml[^>]+>\n//;

    # Convert the xhtml doctype into the html5 doctype
    $contents =~ s/<!DOCTYPE [^>]+>\n?/<!DOCTYPE html>\n/;

    # Lots of tags get `xmlns=""` or `xmlns="<xhtml>"`. We never need it.
    $contents =~ s/\s+xmlns="[^"]*"//g;

    # Strip xml lang tag. We already have the lang tag other places.
    $contents =~ s/\s+xml:lang="[^"]*"//g;

    # Strip the generator tag because we don't need it
    $contents =~ s|<meta name="generator" content="[^"]+" />||g;

    # Add a trailing newline because good documents have trailing newlines
    $contents =~ s/\s*$/\n/;

    return $contents;
}

my $Autosense_RE = qr{
        (<pre \s class="programlisting[^>]+>
         ((?:(?!</pre>).)+?)
         </pre>
         </div>
         <div \s class="(?:console|sense|kibana)_widget" \s data-snippet="
        )
        :(?:CONSOLE|AUTOSENSE|KIBANA):
    }xs;

#===================================
sub _extract_autosense_snippets {
#===================================
    my ( $file, $dest, $contents ) = (@_);
    my $counter  = 1;
    my $filename = $file->basename;
    $filename =~ s/\.html$//;

    my $snippet_dir = $dest->subdir('snippets')->subdir($filename);
    while (
        $contents =~ s|$Autosense_RE|${1}snippets/${filename}/${counter}.json| )
    {
        $snippet_dir->mkpath if $counter == 1;

        # Remove callouts from snippet
        my $snippet = $2;
        $snippet =~ s{<a.+?</i>}{}gs;

        # Unescape HTML entities
        $snippet =~ s/&lt;/</g;
        $snippet =~ s/&gt;/>/g;
        $snippet =~ s/&amp;/&/g;

        # Write snippet
        $snippet_dir->file("$counter.json")
            ->spew( iomode => '>:utf8', $snippet . "\n" );
        $counter++;
    }
    return $contents;
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
sub edit_urls_for_asciidoctor {
#===================================
    my $edit_urls = shift;

    # We'd be better off using a csv library for this but we don't want to add
    # more dependencies to the pl until we go docker-only.
    return join("\n", map { "$_,$edit_urls->{$_}" } keys %{$edit_urls});
}

#===================================
sub _format_alternatives {
#===================================
    my $alternatives = shift;

    # We'd be better off using a csv library for this but it'll be ok for now.
    return 'alternative_language_lookups=' . join(
        "\n",
        map { $_->{source_lang} . ',' . $_->{alternative_lang} . ',' . $_->{dir} } @{ $alternatives }
    );
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
# Write the redirects managed by nginx and run a basic self test on them.
#
# dest        - file to which to write the redirecs : Path::Class::file
# docs_dir    - directory containing generated docs : Path::Class::dir
# temp_dir    - directory for writing temporary files : Path::Class::file
#===================================
sub write_nginx_redirects {
#===================================
    my ( $dest, $docs_dir, $temp_dir ) = @_;

    my $redirects = dir('resources')->file('legacy_redirects.conf')
            ->slurp( iomode => "<:encoding(UTF-8)" );

    # Today we just have a list of redirects built long ago that we include
    # in the generated docs. In the future we'll generate the redirects from
    # the docs *somehow*.

    $redirects =~ s/^(#.+)?\n//gm;

    $dest->spew( iomode => '>:utf8', $redirects );

    my $test_nginx_conf = $temp_dir->file( 'nginx.conf' );
    write_nginx_test_config( $test_nginx_conf, $docs_dir, $dest, 0, 0 );
    run( qw(nginx -t -c), $test_nginx_conf );
}

#===================================
# Build an nginx config file useful for serving the docs locally or running
# a self test on the redirects.
#
# dest            - file to which to write the test config : Path::Class::file
# docs_dir        - directory containing generated docs : Path::Class::dir
# redirects_file  - file containing redirects or 0 if there aren't
#                 - any redirects : Path::Class::file||0
# waching_web     - Truthy if we are watching web resources.
# preview_enabled - Truthy if the preview application is running and we should
#                   delegate to that.
#===================================
sub write_nginx_test_config {
#===================================
    my ( $dest, $docs_dir, $redirects_file, $watching_web, $preview_enabled ) = @_;

    my $redirects_line = $redirects_file ? "include $redirects_file;\n" : '';
    my $web_conf;
    if ( $watching_web ) {
        $web_conf = <<"CONF"
    rewrite ^/guide/static/docs\\.js(.*)\$ /guide/static/docs_js/index.js\$1 last;
    location ^~ /guide/static/jquery.js {
      alias /node_modules/jquery/dist/jquery.js;
      types {
        application/javascript js;
      }
    }
    location ^~ /guide/static/ {
      proxy_pass http://0.0.0.0:1234;
    }
CONF
    } else {
        $web_conf = '';
    }

    my $guide_conf;
    if ( $preview_enabled ) {
        $guide_conf = <<"CONF"
    location ~/(guide|diff) {
      proxy_pass http://0.0.0.0:3000;
      proxy_http_version 1.1;
      proxy_set_header Host \$host;
      proxy_cache_bypass \$http_upgrade;
      proxy_buffering off;
      gzip on;
      add_header 'Access-Control-Allow-Origin' '*';
      if (\$request_method = 'OPTIONS') {
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
        add_header 'Access-Control-Allow-Headers' 'kbn-xsrf-token';
      }
    }
CONF
    } else {
        $guide_conf = <<"CONF"
    location /guide {
      alias $docs_dir;
      add_header 'Access-Control-Allow-Origin' '*';
      if (\$request_method = 'OPTIONS') {
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
        add_header 'Access-Control-Allow-Headers' 'kbn-xsrf-token';
      }
    }
CONF
    }

    my $nginx_conf = <<"CONF";
daemon off;
error_log /dev/stdout info;
pid /run/nginx/nginx.pid;

events {
  worker_connections 64;
}

http {
  error_log /dev/stdout crit;
  log_format short '[\$time_local] "\$request" \$status';
  access_log /dev/stdout short;

  server {
    listen 8000;
    location = / {
      return 301 /guide/index.html;
    }
$web_conf
$guide_conf
    location / {
      alias /docs_build/resources/web/static/;
      autoindex off;
    }
    types {
      application/javascript js;
      image/gif gif;
      image/jpeg jpg;
      image/jpeg jpeg;
      image/svg+xml svg;
      text/css css;
      text/html html;
    }
    rewrite ^/assets/(.+)\$ https://www.elastic.co/assets/\$1 permanent;
    rewrite ^/gdpr-data\$ https://www.elastic.co/gdpr-data permanent;
    rewrite ^/static/(.+)\$ https://www.elastic.co/static/\$1 permanent;
$redirects_line
  }
}
CONF
    $dest->spew( iomode => '>:utf8', $nginx_conf );
}

#===================================
# Build an nginx config file useful for serving a preview of all built docs.
#
# dest            - file to which to write the test config : Path::Class::file
#===================================
sub write_nginx_preview_config {
#===================================
    my ( $dest ) = @_;

    my $preview_conf = <<"CONF";
      proxy_pass http://0.0.0.0:3000;
      proxy_http_version 1.1;
      proxy_set_header Host \$host;
      proxy_cache_bypass \$http_upgrade;
      proxy_buffering off;
      gzip on;
      add_header 'Access-Control-Allow-Origin' '*';
      if (\$request_method = 'OPTIONS') {
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
        add_header 'Access-Control-Allow-Headers' 'kbn-xsrf-token';
      }
CONF
    # We log the X-Opaque-Id which is a header that Elasticsearch uses to mark
    # requests with an id that is opaque to Elasticsearch. Presumably this is
    # a standard. Either way we follow along. We use it in our tests so we can
    # figure out which request came from which test. That is the only reason
    # we *need* it right now. Presumably we'll find some other use for it later
    # though. Think of it as a distributed trace id.
    my $nginx_conf = <<"CONF";
daemon off;
error_log /dev/stdout info;
pid /run/nginx/nginx.pid;

events {
  worker_connections 64;
}

http {
  error_log /dev/stdout crit;
  log_format short '\$http_x_opaque_id \$http_host \$request \$status';
  access_log /dev/stdout short;

  server {
    listen 8000;
    location = / {
      return 301 /guide/index.html;
    }
    location = /robots.txt {
      return 200 "User-agent: *\nDisallow: /\n";
    }
    location ~/(guide|diff) {
$preview_conf
    }
    location / {
      alias /docs_build/resources/web/static/;
      try_files \$uri \@preview;
      autoindex off;
    }
    location \@preview {
$preview_conf
    }
    rewrite ^/assets/(.+)\$ https://www.elastic.co/assets/\$1 permanent;
    rewrite ^/gdpr-data\$ https://www.elastic.co/gdpr-data permanent;
    rewrite ^/static/(.+)\$ https://www.elastic.co/static/\$1 permanent;
  }
}
CONF
    $dest->spew( iomode => '>:utf8', $nginx_conf );
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
sub start_web_resources_watcher {
#===================================
    my $parcel_pid = fork;
    return $parcel_pid if $parcel_pid;

    close STDIN;
    open( STDIN, "</dev/null" );
    exec( qw(/node_modules/parcel/bin/cli.js serve
             --public-url /guide/static/
             --hmr-port 8001
             -d /tmp/parcel/
             resources/web/docs_js/index.js resources/web/styles.pcss) );
}

#===================================
sub start_preview {
#===================================
    my ( $command, $root, $default_template, $ignore_host ) = @_;

    my $preview_pid = fork;
    return $preview_pid if $preview_pid;

    close STDIN;
    open( STDIN, "</dev/null" );
    exec( qw(node --max-old-space-size=128 /docs_build/preview/cli.js),
          $command, $root,
          '--default-template', $default_template,
          ( $ignore_host ? ('--ignore-host') : () )
    );
}

#===================================
sub build_web_resources {
#===================================
    my ( $dest ) = @_;

    my $parcel_out = dir('/tmp/parcel');
    my $compiled_js = $parcel_out->file('docs_js/index.js');
    my $compiled_css = $parcel_out->file('styles.css');

    unless ( -e $compiled_js && -e $compiled_css ) {
        # We write the compiled js and css to /tmp so we can use them on
        # subsequent runs in the same container. This doesn't come up when you
        # build docs either with --doc or --all *but* it comes up all the time
        # when you run the integration tests and saves about 1.5 seconds on
        # every docs build.
        say "Compiling web resources";
        run '/node_modules/parcel/bin/cli.js', 'build',
            '--public-url', '/guide/static/',
            '--experimental-scope-hoisting', '--no-source-maps',
            '-d', $parcel_out,
            'resources/web/docs_js/index.js', 'resources/web/styles.pcss';
        die "Parcel didn't make $compiled_js" unless -e $compiled_js;
        die "Parcel didn't make $compiled_css" unless -e $compiled_css;
    }

    my $static_dir = $dest->subdir( 'raw' )->subdir( 'static' );
    $static_dir->mkpath;
    my $js = $static_dir->file( 'docs.js' );
    my $css = $static_dir->file( 'styles.css' );
    my $js_licenses = file( 'resources/web/docs.js.licenses' );
    my $css_licenses = file( 'resources/web/styles.css.licenses' );
    $js->spew(
        iomode => '>:utf8',
        $js_licenses->slurp( iomode => '<:encoding(UTF-8)' ) . $compiled_js->slurp( iomode => '<:encoding(UTF-8)' )
    );
    $css->spew(
        iomode => '>:utf8',
        $css_licenses->slurp( iomode => '<:encoding(UTF-8)' ) . $compiled_css->slurp( iomode => '<:encoding(UTF-8)' )
    );

    for ( $parcel_out->children ) {
        next unless /.+\.woff2?/;
        rcopy( $_, $static_dir );
    }

    rcopy( '/node_modules/jquery/dist/jquery.min.js', $static_dir->file( 'jquery.js' ) );

    # The public site can't ready anything from the raw directory so we have to
    # copy the static files to html as well.
    my $templated_dir = $dest->subdir( 'html' )->subdir( 'static' );
    $templated_dir->mkpath;
    rcopy( $static_dir, $templated_dir );

    # Copy the template to the root of the repo so we can apply it on the fly.
    # NOTE: We only apply it on the fly for preview right now.
    for ( qw(template air_gapped_template) ) {
        my $template_source = file("resources/web/$_.html");
        my $template = $dest->file("$_.html");
        rcopy( $template_source, $template );
    }
}

1
