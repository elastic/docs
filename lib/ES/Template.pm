package ES::Template;

use strict;
use warnings;
use v5.10;
use Encode qw(encode_utf8);
use Path::Class qw(file);
use File::Copy::Recursive qw(rcopy);
use JSON;
use ES::Util qw(run);

#===================================
sub new {
#===================================
    my ( $class, %args ) = @_;

    my $template = file( "resources/web/template.html" );
    my $content = $template->slurp( iomode => '<:encoding(UTF-8)' );
    my @parts = split /<!-- (DOCS \w+) -->/, $content;
    my %map;

    for my $i ( 0 .. @parts - 1 ) {
        if ( $parts[$i] =~ s/^DOCS (\w+)$// ) {
            $parts[$i] = '';
            $map{$1} = $i;
        }
    }

    return bless {
        json => JSON->new->pretty->utf8->canonical,
        map => \%map,
        parts => \@parts,
    }, $class;
}

#===================================
sub apply {
#===================================
    my ( $self, $source_dir, $dest_dir, $lang, $asciidoctor,
         $alternatives_summary, $is_toc) = @_;

    my $map = $self->{map};

    my $initial_js_state = $self->_build_initial_js_state( $alternatives_summary );

    for my $source ( $source_dir->children ) {
        my $dest = $dest_dir->file( $source->relative( $source_dir ) );
        if ( $source->is_dir ) {
            # Usually books are built to empty directories and any
            # subdirectories contain images or snippets and should be copied
            # wholesale into the templated directory. But the book's
            # multi-version table of contents is different because it is built
            # to the root directory of all book versions so subdirectories are
            # other books! Copying them would overwrite the templates book
            # files with untemplated book files. That'd be bad!
            rcopy( $source, $dest ) unless $is_toc;
            next;
        }
        if ( $source->basename !~ /\.html$/ ) {
            rcopy( $source, $dest );
            next;
        }

        my $contents = $source->slurp( iomode => '<:encoding(UTF-8)' );

        # Strip XML guff
        $contents =~ s/\s+xmlns="[^"]*"//g;
        $contents =~ s/\s+xml:lang="[^"]*"//g;
        $contents =~ s/^<\?xml[^>]+>\n//;
        $contents =~ s/\s*$/\n/;

        # Extract AUTOSENSE snippets
        $contents = $self->_autosense_snippets( $source, $contents ) unless $asciidoctor;

        # Fill in template
        my @parts  = @{ $self->{parts} };
        my ($head) = ( $contents =~ m{<head>(.+?)</head>}s );
        my ($body) = ( $contents =~ m{<body>(.+?)</body>}s );
        $parts[ $map->{PREHEAD} ] = $head;
        $parts[ $map->{LANG} ] = qq(lang="$lang");
        $parts[ $map->{BODY} ] = $body;
        $parts[ $map->{FINAL} ] = $initial_js_state;

        $dest->spew( iomode => '>:utf8', join "", @parts );
    }
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
sub _autosense_snippets {
#===================================
    my ( $self, $file, $contents ) = (@_);
    my $counter  = 1;
    my $filename = $file->basename;
    $filename =~ s/\.html$//;

    my $snippet_dir = $file->parent->subdir('snippets')->subdir($filename);
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
sub _build_initial_js_state {
#===================================
    my ( $self, $alternatives_summary ) = ( @_ );

    # Try an keep this state small and from changing frequently because it is
    # included in every html page.
    my %state;

    if ( -f $alternatives_summary ) {
        my %summary;
        my $alts = $alternatives_summary->slurp( iomode => '<:encoding(UTF-8)' );
        $alts = $self->{json}->decode($alts);

        while (my ($sourceLang, $sEntry) = each (%{ $alts })) {
            $summary{$sourceLang} = {};
            while (my ($altLang, $aEntry) = each (%{ $sEntry->{alternatives} })) {
                $summary{$sourceLang}{$altLang} = {};
                my $hasAny = $aEntry->{found} > 0 ? \1 : \0;
                $summary{$sourceLang}{$altLang}{hasAny} = $hasAny;
            }
        }
        $state{alternatives} = \%summary;
    }

    my $txt = $self->{json}->encode(\%state);
    return <<"HTML";
<script type="text/javascript">
window.initial_state = $txt</script>
HTML
}

1;
