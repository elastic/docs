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

        push @sources,
            {
            repo    => ES::Repo->get_repo( $_->{repo} ),
            path    => $path,
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
    return $first->{repo}->edit_url($branch);
}

#===================================
sub has_changed {
#===================================
    my $self   = shift;
    my $title  = shift;
    my $branch = shift;
    for my $source ( $self->_sources_for_branch($branch) ) {
        return 1
            if $source->{repo}->has_changed( $title, $branch, $source->{path} );
    }
    return;
}

#===================================
sub mark_done {
#===================================
    my $self   = shift;
    my $title  = shift;
    my $branch = shift;
    for my $source ( $self->_sources_for_branch($branch) ) {
        $source->{repo}->mark_done( $title, $branch, $source->{path} );
    }
    return;
}

#===================================
sub dump_recent_commits {
#===================================
    my $self   = shift;
    my $title  = shift;
    my $branch = shift;
    my $text   = '';
    for my $source ( $self->_sources_for_branch($branch) ) {
        $text
            .= $source->{repo}
            ->dump_recent_commits( $title, $branch, $source->{path} );
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
        my $repo = $source->{repo};
        my $path = $source->{path};

        # check that we're not overwriting files with subsequent repos
        for my $file ( $repo->tree( $branch, $path ) ) {
            $entries{$file}++
                && die "File <$file> already exists while checking out repo <"
                . $repo->name
                . ">, branch <$branch>";
        }

        # Extract files into dest, removing the path prefix
        $repo->extract( $branch, $path, $dest );

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
