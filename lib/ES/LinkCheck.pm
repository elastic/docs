package ES::LinkCheck;

use strict;
use warnings;
use v5.10;
use ES::Util qw(run);

our $Link_Re = qr{
    (?:https?://(?:www.)?elastic.co|[\s"])/guide/
    ([^"\#<>\s]+)           # path
    (?:\#([^"<>\s]+))?      # fragment
}x;

#===================================
sub new {
#===================================
    my $class = shift;
    my $root = shift or die "No root dir specified";
    bless { root => $root, seen => {}, bad => {} }, $class;
}

#===================================
sub check {
#===================================
    my $self = shift;
    my $dir  = $self->root;

    $self->root->recurse(
        callback => sub {
            my $item = shift;

            if ( $item->is_dir ) {
                return $item->PRUNE
                    if $item->basename eq 'images';
                return;
            }
            $self->check_file($item)
                if $item->basename =~ /\.html$/;
        }
    );
    return $self->has_bad;

}

#===================================
sub check_file {
#===================================
    my ( $self, $file, $extract, $file_descr ) = @_;
    $file_descr ||= "$file";
    my $source = $file->slurp( iomode => '<:encoding(UTF-8)' );
    return $self->check_source( $source, $extract, $file_descr );
}

#===================================
sub check_source {
#===================================
    my ( $self, $source, $extract, $file_descr ) = @_;
    $extract ||= \&_link_extractor;

    my $link_it = $extract->($source);
    my $seen    = $self->seen;

    while ( my ( $path, $fragment ) = $link_it->() ) {
        my $dest = $self->root->file($path);
        unless ( $self->_file_exists( $dest, $path ) ) {
            $self->add_bad( $file_descr, $path );
            next;
        }
        next unless $fragment;
        unless ( $self->_fragment_exists( $dest, $path, $fragment ) ) {
            $self->add_bad( $file_descr, "$path#$fragment" );
        }
    }
}

#===================================
sub _link_extractor {
#===================================
    my $contents = shift;
    return sub {
        while ( $contents =~ m{$Link_Re}g ) {
            return ( $1, $2 );
        }
        return;
    };
}

#===================================
sub report {
#===================================
    my $self = shift;
    my $bad  = $self->bad;
    return "All cross-document links OK"
        unless keys %$bad;

    my @error = "Bad cross-document links:";
    for my $file ( sort keys %$bad ) {
        push @error, "  $file contains broken links to:";
        push @error, map {"   - $_"} sort keys %{ $bad->{$file} };
    }
    warn join "\n", @error, '';
}

#===================================
sub _file_exists {
#===================================
    my ( $self, $file, $path ) = @_;
    my $seen = $self->seen;
    $seen->{$path} = -e $file
        unless exists $seen->{$path};

    return $seen->{$path};
}

#===================================
sub _fragment_exists {
#===================================
    my ( $self, $file, $path, $frag ) = @_;
    my $seen = $self->seen;

    unless ( exists $seen->{"$path#$frag"} ) {
        my $content = $file->slurp( iomode => '<:encoding(UTF-8)' );
        $content =~ s{.+<!-- start body -->}{}s;
        $content =~ s{<!-- end body -->.+}{}s;
        while ( $content =~ m{<\w+ [^>]*id="([^"]+)"}g ) {
            $seen->{"$path#$1"} = 1;
        }
    }
    return $seen->{"$path#$frag"} ||= 0;
}

#===================================
sub add_bad {
#===================================
    my ( $self, $file, $id ) = @_;
    $self->bad->{$file}{$id} = 1;
}

#===================================
sub root    { shift->{root} }
sub seen    { shift->{seen} }
sub bad     { shift->{bad} }
sub has_bad { !keys %{ shift->bad } }
#===================================

1
