#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;

use FindBin;
use lib "$FindBin::RealBin/lib";
use ES::Util qw($Opts);
use Getopt::Long;
use Path::Class qw(dir file);

GetOptions( $Opts, 'version=s', 'action=s', 'dir=s', "new=s" );

my $dir = $Opts->{dir} or usage("No <dir> specified");
$dir = dir($dir);

my $action = $Opts->{action} or usage("No <action> specified");
if ( $action eq 'list' ) {
    list($dir);
    exit;
}

my $version = $Opts->{version} or usage("No <version> specified");
my $new;
if ( $action eq 'replace' ) {
    $new = $Opts->{new} or usage("No <new> version specified");
}

my $cb
    = $action eq 'release'   ? release($version)
    : $action eq 'unrelease' ? unrelease($version)
    : $action eq 'strip'     ? strip($version)
    : $action eq 'replace' ? replace( $version, $new )
    :                        usage( "Unknown action: " . $action );

update( dir( $Opts->{dir} ), $cb );
list($dir);

#===================================
sub list {
#===================================
    my $dir = shift;
    my $re  = qr/\b(added|deprecated|coming)\[([^],]+)[^]]*\]/;
    my %versions;
    $dir->recurse(
        callback => sub {
            my $child = shift;
            return $child->PRUNE if $child->basename =~ /^\./;
            return if $child->is_dir;
            my $text = $child->slurp;
            while ( $text =~ /$re/g ) {
                $versions{$2}{$1}++;
            }
        }
    );
    print "Version          Added  Coming  Deprecated\n";
    print "------------------------------------------\n";

    for my $version ( sort keys %versions ) {
        printf "%-15s:   %3d     %3d      %3d\n",
            $version,
            map { $versions{$version}{$_} || 0 } qw(added coming deprecated);
    }
}

#===================================
sub release {
#===================================
    my $version = shift;
    sub {
        my $text = shift;
        $text =~ s/coming\[${version}([^\]]*)?\]/added[$version$1]/g;
        return $text;
        }
}

#===================================
sub unrelease {
#===================================
    my $version = shift;
    sub {
        my $text = shift;
        $text =~ s/added\[${version}([^\]]*)?\]/coming[$version$1]/g;
        return $text;
        }
}

#===================================
sub strip {
#===================================
    my $version = shift;
    my $note_re = qr/(?:added|deprecated|coming)\[${version}[^]]*\]\.?/;
    sub {
        my $text = shift;

        # block macro
        $text =~ s/^${note_re}([ ]*\n|\Z){1,2}//gm;
        $text =~ s/
            (?<=\S)[ ]+${note_re}  # with text before
          | ${note_re}[ ]*(?=\S)   # with text after
          | ^[ ]*${note_re}[ ]*$   # alone on line
        //gmx;
        return $text;
        }
}

#===================================
sub replace {
#===================================
    my ( $old, $new ) = @_;
    no warnings 'uninitialized';
    sub {
        my $text = shift;
        $text
            =~ s/(coming|added|deprecated)\[${old}\s*(,[^\]]*)?\]/${1}[$new$2]/g;
        return $text;
    };
}

#===================================
sub update {
#===================================
    my ( $dir, $cb ) = @_;
    $dir->recurse(
        callback => sub {
            my $child = shift;
            return $child->PRUNE if $child->basename =~ /^\./;
            return if $child->is_dir;
            my $old = $child->slurp;
            my $new = $cb->($old);
            return if $new eq $old;
            print "Updating: $child\n";
            $child->spew($new);
        }
    );
}

#===================================
sub init_env {
#===================================
    chdir($FindBin::RealBin) or die $!;

    $ENV{SGML_CATALOG_FILES} = $ENV{XML_CATALOG_FILES} = join ' ',
        file('resources/docbook-xsl-1.78.1/catalog.xml')->absolute,
        file('resources/docbook-xml-4.5/catalog.xml')->absolute;

    $ENV{PATH}
        = dir('resources/asciidoc-8.6.8/')->absolute . ':' . $ENV{PATH};

    eval { run( 'xsltproc', '--version' ) }
        or die "Please install <xsltproc>";
}

#===================================
sub usage {
#===================================
    my $error = shift;

    if ($error) {
        say "\nError: $error";
    }
    say <<USAGE;

        $0 --dir path/to/dir --action list
     OR
        $0 --dir path/to/dir --version 0.90.5 --action strip|release|unrelease
     OR
        $0 --dir path/to/dir --version 0.90.5 --action replace --new 0.90.5.Beta

    Actions:
      strip:     removes added/deprecated/coming notes
      release:   changes coming notes to added notes
      unrelease: changes added notes to coming notes
      replace:   replace one version with another
USAGE

    exit !!$error;
}
