package ES::Template;

use strict;
use warnings;
use v5.10;
use Data::Dumper qw(Dumper);
use Encode qw(decode_utf8 encode_utf8);
use Digest::MD5 qw(md5_hex);
use Path::Class qw(dir);
use ES::Util qw(get_url);

#===================================
sub new {
#===================================
    my ( $class, %args ) = @_;

    my $path = $args{path}
        or die "No <path> specified: " . Dumper( \%args );

    my $base_url = $args{base_url}
        or die "No <base_url> specified: " . Dumper( \%args );

    my $template_url = $args{template_url}
        or die "No <template_url> specified: " . Dumper( \%args );

    my $defaults = $args{defaults} || {};
    my $lenient  = $args{lenient}  || 0;

    my $self = bless {
        path         => dir($path),
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
    my $map  = $self->_map;

    for my $file ( $dir->children ) {
        next if $file->is_dir or $file->basename !~ /\.html$/;
        my $contents = $file->slurp( iomode => '<:encoding(UTF-8)' );
        $contents =~ s/\s+xmlns="[^"]*"//g;
        $contents =~ s/\s+xml:lang="[^"]*"//g;
        $contents =~ s/^<\?xml[^>]+>\n//;
        $contents =~ s/\s+$//;
        $contents .= "\n";
        my @parts  = @{ $self->_parts };
        my ($head) = ( $contents =~ m{<head>(.+?)</head>}s );
        my ($body) = ( $contents =~ m{<body>(.+?)</body>}s );
        $parts[ $map->{PREHEAD} ] = $head;
        $parts[ $map->{BODY} ]
            = "<!-- start body -->\n$body\n<!-- end body -->\n";

        $file->spew( iomode => '>:utf8', join "", @parts );
    }
    $dir->file('template.md5')->spew( $self->md5 );
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

    my ( $new, $old );
    ($old) = $self->path->children( no_hidden => 1 );

    my $created = $old ? $old->basename : 0;
    $created =~ s/\.html//;
    if ( not $force and time - $created < 24 * 60 * 60 ) {
        $new = $old;
    }
    else {
        $new = eval { $self->_fetch_template() };
        if ($new) {
            $old->remove if $old and $old ne $new;
        }
        elsif ( $self->lenient && $old ) {
            print "$@Reusing existing template\n";
            $new = $old;
        }
        else {
            die $@;
        }
    }
    $self->_load_template($new);
    return $self;
}

#===================================
sub _fetch_template {
#===================================
    my $self = shift;
    my $template;
    eval {
        my $content = eval { get_url( $self->template_url ); }
            or die "URL <" . $self->template_url . "> returned [$@]\n";

        # remove title
        $content =~ s{<title>.*</title>}{}s
            or die "Couldn't remove <title>\n";

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

        $template = $self->path->file( time . ".html" );
        $template->spew( iomode => '>:utf8', $content );
        1;
    } or die "Unable to update template: $@";
    return $template;
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
#===================================

1;
