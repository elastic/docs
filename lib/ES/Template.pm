package ES::Template;

use strict;
use warnings;
use v5.10;
use Encode qw(encode_utf8);
use Digest::MD5 qw(md5_hex);
use Path::Class qw(file);
use File::Copy::Recursive qw(fcopy);

#===================================
sub new {
#===================================
    my ( $class, %args ) = @_;

    my $self = bless {
        defaults     => $args{defaults},
        abs_urls     => $args{abs_urls} || 0,
    }, $class;
    $self->_init;
}

#===================================
sub apply {
#===================================
    my $self = shift;
    my $dir  = shift;
    my $lang = shift || die "No lang specified";
    my $asciidoctor = shift;

    my $map = $self->{map};

    for my $file ( $dir->children ) {
        next if $file->is_dir or $file->basename !~ /\.html$/;
        my $contents = $file->slurp( iomode => '<:encoding(UTF-8)' );

        # Strip XML guff
        $contents =~ s/\s+xmlns="[^"]*"//g;
        $contents =~ s/\s+xml:lang="[^"]*"//g;
        $contents =~ s/^<\?xml[^>]+>\n//;
        $contents =~ s/\s*$/\n/;

        # Extract AUTOSENSE snippets
        $contents = $self->_autosense_snippets( $file, $contents ) unless $asciidoctor;

        # Fill in template
        my @parts  = @{ $self->{parts} };
        my ($head) = ( $contents =~ m{<head>(.+?)</head>}s );
        my ($body) = ( $contents =~ m{<body>(.+?)</body>}s );
        $parts[ $map->{PREHEAD} ] = $head;
        $parts[ $map->{LANG} ]    = qq(lang="$lang");
        $parts[ $map->{BODY} ]
            = "<!-- start body -->\n$body\n<!-- end body -->\n";

        $file->spew( iomode => '>:utf8', join "", @parts );
    }

    # Copy stylesheet
    fcopy( 'resources/web/styles.css', $dir )
        or die "Couldn't copy <styles.css> to <$dir>: $!";

    # Copy javascript
    fcopy( 'resources/web/docs.js', $dir )
        or die "Couldn't copy <docs.js> to <$dir>: $!";

    $dir->file('template.md5')->spew( $self->{md5} );
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
        $snippet =~ s{<a.+?</span>}{}gs;

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
sub md5_changed {
#===================================
    my $self = shift;
    my $dir  = shift;
    my $file = $dir->file('template.md5');
    return !eval { $file->slurp eq $self->{md5}; };
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
    my $abs = $self->{abs_urls} ? 'https://www.elastic.co/' : '';
    my %map;

    for my $i ( 0 .. @parts - 1 ) {
        if ( $parts[$i] =~ s/^DOCS (\w+)$// ) {
            $parts[$i] = $defaults->{$1} || '';
            $map{$1} = $i;
        }
        if ($abs) {
            $parts[$i] =~ s{
                (<(?:script|link|img)[^>]*)
                (\b(?:src|href)=")/(?=\w)
            }{$1 $2$abs}xg;
        }
    }

    $self->{map}   = \%map;
    $self->{parts} = \@parts;
    $self->{md5}   = md5_hex( join "", map { encode_utf8 $_} @parts );
    return $self;
}

1;
