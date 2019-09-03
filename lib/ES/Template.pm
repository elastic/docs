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

    my $self = bless {
        defaults => $args{defaults},
        json => JSON->new->pretty->utf8->canonical,
    }, $class;
    $self->_init;
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
        $parts[ $map->{LANG} ]    = qq(lang="$lang");
        $parts[ $map->{BODY} ]
            = "<!-- start body -->\n$body\n<!-- end body -->\n";
        $parts[ $map->{FINAL} ] = $initial_js_state . $parts[ $map->{FINAL} ];

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
sub _init {
#===================================
    my $self = shift;

    my $template = file("resources/web/template.html");
    my $content;
    eval {
        $content = $template->slurp( iomode => '<:encoding(UTF-8)' );;

        # remove title
        $content =~ s{<title>.*</title>}{}s
            or die "Couldn't remove <title>\n";

        # remove guide_template.css
        $content =~ s{<[^<>]+guide_template.css"[^>]+>}{};

        # remove visitor count and mod_value
        $content =~ s{<script[^>]+>visitor_count[^>]+>}{};
        $content =~ s{<script[^>]+>mod_value[^>]+>}{};

        # remove meta date and DC.title
        $content =~ s{<meta name=.date.[^>]+>}{};
        $content =~ s{<meta name=.published_date.[^>]+>}{};
        $content =~ s{<meta name=.DC.title.[^>]+>}{};

        # prehead
        $content =~ s{(<head>)}{$1\n<!-- DOCS PREHEAD -->}
            or die "Couldn't add PREHEAD\n";

        # posthead
        $content =~ s{(</head>)}{\n<!-- DOCS POSTHEAD -->\n$1}
            or die "Couldn't add POSTHEAD\n";

        # lang
        $content =~ s{(<section id="guide")}{$1 <!-- DOCS LANG -->};

        # body parts
        $content =~ s{
            (<div [^>]+ class="[^"]*\bguide-section\b[^"]*"[^>]*>)
            .+?
            (<div [^>]+ id="right_col" [^>]*>)
        }{
            $1
            <!-- DOCS BODY -->
            </div>
            $2
        }xs
            or die "Couldn't add BODY tags\n";

        # last in page
        $content =~ s {
            </body>
        }{
            <!-- DOCS FINAL -->
            </body>
        }xs;

        1;
    } or die "Unable to load template: $@";
    my @parts = split /<!-- (DOCS \w+) -->/, $content;
    my $defaults = $self->{defaults};
    my %map;

    for my $i ( 0 .. @parts - 1 ) {
        if ( $parts[$i] =~ s/^DOCS (\w+)$// ) {
            $parts[$i] = $defaults->{$1} || '';
            $map{$1} = $i;
        }
    }

    $self->{map}   = \%map;
    $self->{parts} = \@parts;
    return $self;
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
