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
        my $path   = dir('.')->subdir( $_->{path} )->relative('.');
        my $repo   = ES::Repo->get_repo( $_->{repo} );
        my $prefix = defined $_->{prefix} ? $_->{prefix} : $repo->name;
        my $alternatives = $_->{alternatives} || 0;
        if ($alternatives) {
            die 'source_lang is required' unless $alternatives->{source_lang};
            die 'alternative_lang is required' unless $alternatives->{alternative_lang};
        }
        push @sources, {
            repo    => $repo,
            prefix  => $prefix,
            path    => $path,
            exclude => { map { $_ => 1 } @{ $_->{exclude_branches} || [] } },
            map_branches => $_->{map_branches} || {},
            private => $_->{private} || 0,
            alternatives => $_->{alternatives} || 0,
        };
    }

    bless { sources => \@sources, temp_dir => $args{temp_dir} }, $class;
}

#===================================
sub first {
#===================================
    return shift->_sources->[0];
}

#===================================
sub has_changed {
#===================================
    my $self   = shift;
    my $title  = shift;
    my $branch = shift;
    my $asciidoctor = shift;
    for my $source ( $self->_sources_for_branch($branch) ) {
        my $repo_branch = $source->{map_branches}->{$branch} || $branch;
        return 1
            if $source->{repo}->has_changed( $title, $repo_branch, $source->{path}, $asciidoctor );
    }
    return;
}

#===================================
sub mark_done {
#===================================
    my $self   = shift;
    my $title  = shift;
    my $branch = shift;
    my $asciidoctor = shift;
    for my $source ( $self->_sources_for_branch($branch) ) {
        my $repo_branch = $source->{map_branches}->{$branch} || $branch;
        $source->{repo}->mark_done( $title, $repo_branch, $source->{path}, $asciidoctor );
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
        my $repo_branch = $source->{map_branches}->{$branch} || $branch;
        $text
            .= $source->{repo}
            ->dump_recent_commits( $title, $repo_branch, $source->{path} );
    }
    return $text;
}

#===================================
sub prepare {
#===================================
    my $self   = shift;
    my $title  = shift;
    my $branch = shift;

    my $checkout = Path::Class::tempdir( DIR => $self->temp_dir );
    my %edit_urls = ();
    my $first_path = 0;
    my @alternatives;

    # need to handle repo name here, not in Repo
    for my $source ( $self->_sources_for_branch($branch) ) {
        my $repo   = $source->{repo};
        my $prefix = $source->{prefix};
        my $path   = $source->{path};
        my $source_checkout = $checkout->subdir($prefix);
        my $repo_branch = $source->{map_branches}->{$branch} || $branch;

        $repo->extract( $title, $repo_branch, $path, $source_checkout );
        $edit_urls{ $source_checkout->absolute } = $source->{private} ?
            '<disable>' : $repo->edit_url($repo_branch);
        $first_path = $source_checkout unless $first_path;
        if ( $source->{alternatives} ) {
            push @alternatives, {
                source_lang => $source->{alternatives}->{source_lang},
                alternative_lang => $source->{alternatives}->{alternative_lang},
                dir => $source_checkout->subdir( $source->{path} ),
            };
        }
    }
    return ( $checkout, \%edit_urls, $first_path, \@alternatives );
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
