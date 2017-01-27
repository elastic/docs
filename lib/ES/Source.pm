package ES::Source;

use strict;
use warnings;
use v5.10;
use Path::Class qw(dir file);
use ES::Repo();
use File::Copy::Recursive qw(fcopy rcopy);

#===================================
sub new {
#===================================
    my $class = shift;
    my %args  = @_;

    my @sources;
    for ( @{ $args{sources} } ) {
        my $path = dir('.')->subdir( $_->{path} )->relative('.');
        my $strip
            = defined $_->{strip}
            ? $_->{strip}
            : scalar grep { $_ ne '.' } $path->components;

        push @sources,
            {
            repo    => ES::Repo->get_repo( $_->{repo} ),
            path    => $path,
            strip   => $strip,
            exclude => { map { $_ => 1 } @{ $_->{exclude_branches} || [] } }
            };
    }

    bless { sources => \@sources, temp_dir => $args{temp_dir} }, $class;
}

#===================================
sub edit_url {
#===================================
    my $self   = shift;
    my $branch = shift;
    my $first  = $self->_sources->[0];
    return $first->{repo}->edit_url( $branch, $first->{path} );
}

#===================================
sub has_changed {
#===================================
    my $self   = shift;
    my $branch = shift;
    for my $source ( $self->_sources_for_branch($branch) ) {
        return 1 if $source->{repo}->has_changed( $branch, $source->{path} );
    }
    return;
}

#===================================
sub mark_done {
#===================================
    my $self   = shift;
    my $branch = shift;
    for my $source ( $self->_sources_for_branch($branch) ) {
        $source->{repo}->mark_done( $branch, $source->{path} );
    }
    return;
}

#===================================
sub dump_recent_commits {
#===================================
    my $self   = shift;
    my $branch = shift;
    my $text   = '';
    for my $source ( $self->_sources_for_branch($branch) ) {
        $text
            .= $source->{repo}->dump_recent_commits( $branch, $source->{path} );
    }
    return $text;
}

#===================================
sub prepare {
#===================================
    my $self   = shift;
    my $branch = shift;

    my %entries;
    my $dest = Path::Class::tempdir( DIR => $self->temp_dir );

    for my $source ( $self->_sources_for_branch($branch) ) {
        my $repo  = $source->{repo};
        my $path  = $source->{path};
        my $strip = $source->{strip};

        # check that we're not overwriting files with subsequent repos
        for my $file ( $repo->tree( $branch, $path ) ) {
            my @parts = $file->components;
            splice @parts, 0, $strip;
            $file = file(@parts);
            $entries{$file}++
                && die "File <$file> already exists while checking out repo <"
                . $repo->name
                . ">, branch <$branch>";
        }

        # Extract files into dest, removing the path prefix
        $repo->extract_relative( $branch, $path, $dest, $strip );

    }
    return $dest;
}

#===================================
sub _sources_for_branch {
#===================================
    my $self   = shift;
    my $branch = shift;
    return grep { !$_->{exclude}{$branch} } @{ $self->_sources };
}
#===================================
sub _sources { shift->{sources} }
sub temp_dir { shift->{temp_dir} }
#===================================

1;
