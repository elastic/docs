package ES::Template;

use strict;
use warnings;
use v5.10;
use Data::Dumper qw(Dumper);
use Encode qw(decode_utf8 encode_utf8);
use Digest::MD5 qw(md5_hex);
use Path::Class qw(dir);
use ES::Util qw(get_url);
use YAML qw(LoadFile DumpFile);
use File::Copy::Recursive qw(fcopy);

#===================================
sub new {
#===================================
    my ( $class, %args ) = @_;

    my $path = $args{path}
        or die "No <path> specified: " . Dumper( \%args );
    $path = dir($path);
    $path->mkpath;

    my $base_url = $args{base_url}
        or die "No <base_url> specified: " . Dumper( \%args );

    my $template_url = $args{template_url}
        or die "No <template_url> specified: " . Dumper( \%args );

    my $defaults = $args{defaults} || {};
    my $lenient  = $args{lenient}  || 0;

    my $self = bless {
        path         => $path,
        base_url     => $base_url,
        template_url => $template_url,
        defaults     => $defaults,
        lenient      => $args{lenient} || 0,
        abs_urls     => $args{abs_urls} || 0,
    }, $class;
    $self->_init( $args{force} );
}

#===================================
sub apply {
#===================================
    my $self = shift;
    my $dir  = shift;

    my $map = $self->_map;

    for my $file ( $dir->children ) {
        next if $file->is_dir or $file->basename !~ /\.html$/;
        my $contents = $file->slurp( iomode => '<:encoding(UTF-8)' );

        # Strip XML guff
        $contents =~ s/\s+xmlns="[^"]*"//g;
        $contents =~ s/\s+xml:lang="[^"]*"//g;
        $contents =~ s/^<\?xml[^>]+>\n//;
        $contents =~ s/\s*$/\n/;

        # Extract AUTOSENSE snippets
        $contents = $self->_autosense_snippets( $file, $contents );

        # Fill in template
        my @parts  = @{ $self->_parts };
        my ($head) = ( $contents =~ m{<head>(.+?)</head>}s );
        my ($body) = ( $contents =~ m{<body>(.+?)</body>}s );
        $parts[ $map->{PREHEAD} ] = $head;
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

    $dir->file('template.md5')->spew( $self->md5 );
}

my $Autosense_RE = qr{
        (<pre \s class="programlisting[^>]+>
         ((?:(?!</pre>).)+?)
         </pre>
         </div>
         <div \s class="sense_widget" \s data-snippet="
        )
        :AUTOSENSE:
    }xs;

#===================================
sub _autosense_snippets {
#===================================
    my ( $self, $file, $contents ) = (@_);
    my $counter  = 1;
    my $filename = $file->basename;
    $filename =~ s/\.html$//;

    my $snippet_dir = $file->parent->subdir('snippets')->subdir($filename);
    while ( $contents =~ s|$Autosense_RE|${1}snippets/${filename}/${counter}.json| ) {
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
    return !eval { $file->slurp eq $self->md5; };
}

#===================================
sub _init {
#===================================
    my ( $self, $force ) = @_;

    my $prefix = $self->template_url;
    $prefix =~ s/\W//g;

    my $new = $self->path->file( "$prefix-" . time . ".html" );
    my @old = sort grep {/(^|\/)${prefix}-\d+\.html$/}
        $self->path->children( no_hidden => 1 );

    my $latest = 0;
    if ( @old && $old[-1] =~ /-(\d+)\.html/ ) {
        $latest = $1;
    }

    my $created = $1 || 0;
    if ( not $force and time - $latest < 20 * 60 ) {
        $new = $old[-1];
    }
    else {
        my $template = eval { $self->_update_template() };
        if ($template) {
            $_->remove for @old;
            $new->spew( iomode => '>:utf8', $template );
        }
        elsif ( $self->lenient && @old ) {
            print "$@Reusing existing template\n";
            $new = $old[-1];
        }
        else {
            die $@;
        }
    }
    $self->_load_template($new);
    return $self;
}

#===================================
sub _update_template {
#===================================
    my $self = shift;
    my $content;
    eval {
        $content = $self->_fetch_template;

        # remove title
        $content =~ s{<title>.*</title>}{}s
            or die "Couldn't remove <title>\n";

        # remove guide_template.css
        $content =~ s{<[^<>]+guide_template.css"[^>]+>}{};

        # prehead
        $content =~ s{(<head>)}{$1\n<!-- DOCS PREHEAD -->}
            or die "Couldn't add PREHEAD\n";

        # posthead
        $content =~ s{(</head>)}{\n<!-- DOCS POSTHEAD -->\n$1}
            or die "Couldn't add POSTHEAD\n";

        # body parts
        $content =~ s{
            <div \s+ id="pageheader"
            .+?
            (<div \s+ id="rtpcontainer")
        }{
            <!-- DOCS PREBODY -->
            <!-- DOCS BODY -->
            <!-- DOCS POSTBODY -->
            $1
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
    } or die "Unable to update template: $@";
    return $content;
}

#===================================
sub _fetch_template {
#===================================
    my $self = shift;

    my $content;
    my $cred = $self->_creds_for_url();

    eval { $content = get_url( $self->template_url, $cred ) }
        and return $content;

    die $@ unless $@ =~ m/401 Unauthorized|error: 401/;

    say
        "The docs template is password protected. Please enter your credentials:";

    $|++;
    print "Username: ";
    my $user = <STDIN>;
    chomp $user;
    exit unless $user;

    print "Password: ";
    my $pass = <STDIN>;
    chomp $pass;
    exit unless $pass;

    $self->_add_creds_for_url("$user:$pass");
    return $self->_fetch_template;
}

#===================================
sub _creds_for_url {
#===================================
    my $self = shift;
    my $creds = eval { LoadFile $self->creds_file } || {};
    return $creds->{ $self->template_url };
}

#===================================
sub _add_creds_for_url {
#===================================
    my ( $self, $cred ) = @_;
    my $creds = eval { LoadFile $self->creds_file } || {};
    $creds->{ $self->template_url } = $cred;
    DumpFile( $self->creds_file, $creds );
}

#===================================
sub _load_template {
#===================================
    my ( $self, $template ) = @_;
    my $html = $template->slurp( iomode => '<:encoding(UTF-8)' );

    my @parts = split /<!-- (DOCS \w+) -->/, $html;

    my $defaults = $self->defaults;
    my $abs = $self->abs_urls ? $self->base_url : '';
    my %map;

    for my $i ( 0 .. @parts - 1 ) {
        if ( $parts[$i] =~ s/^DOCS (\w+)$// ) {
            $parts[$i] = $defaults->{$1} || '';
            $map{$1} = $i;
        }
        if ($abs) {
            $parts[$i] =~ s{
                (<(?:script|link)[^>]*)
                (\b(?:src|href)=")/(?=\w)
            }{$1 $2$abs}xg;
        }
    }

    $self->{map}   = \%map;
    $self->{parts} = \@parts;
    $self->{md5}   = md5_hex( join "", map { encode_utf8 $_} @parts );

}

#===================================
sub path         { shift->{path} }
sub base_url     { shift->{base_url} }
sub template_url { shift->{template_url} }
sub lenient      { shift->{lenient} }
sub defaults     { shift->{defaults} }
sub abs_urls     { shift->{abs_urls} }
sub md5          { shift->{md5} }
sub _map         { shift->{map} }
sub _parts       { shift->{parts} }
sub creds_file   { shift->path->file('creds.yml') }
#===================================

1;
