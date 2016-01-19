package ES::LinkCheck;

use strict;
use warnings;
use v5.10;
use ES::Util qw(run);

our $Link_Re = qr{
    https?://(?:www.)?elastic.co/guide/
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

    $dir->recurse(
        callback => sub {
            my $item = shift;

            if ( $item->is_dir ) {
                return $item->PRUNE
                    if $item->basename eq 'images';
                return;
            }
            $self->_check_links( $dir, $item )
                if $item->basename =~ /\.html$/;
        }
    );
    return !keys %{ $self->bad };

}

#===================================
sub check_file {
#===================================
    my $self = shift;
    my $file = shift;
    my $dir  = $self->root;

    $self->_check_links( $dir, $file );
    return !keys %{ $self->bad };

}

#===================================
sub _check_links {
#===================================
    my ( $self, $dir, $file ) = @_;

    my $contents = $file->slurp( iomode => '<:encoding(UTF-8)' );
    my $seen = $self->seen;

    while ( $contents =~ m{$Link_Re}g ) {
        my $path     = $1;
        my $fragment = $2;
        my $dest     = $dir->file($path);
        unless ( $self->_file_exists( $dest, $path ) ) {
            $self->add_bad( $file, $path );
            next;
        }
        next unless $fragment;
        unless ( $self->_fragment_exists( $dest, $path, $fragment ) ) {
            $self->add_bad( $file, "$path#$fragment" );
        }
    }
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
        push @error, "  $file:";
        push @error, map {"   - $_"} sort keys %{ $bad->{$file} };
    }
    die join "\n", @error, '';

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
sub root { shift->{root} }
sub seen { shift->{seen} }
sub bad  { shift->{bad} }
#===================================

1
