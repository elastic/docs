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
        my $repo   = ES::Repo->get_repo( $_->{repo} );
        my $prefix = defined $_->{prefix} ? $_->{prefix} : $repo->name;
        my $path   = dir('.')->subdir( $_->{path} )->relative('.');
        my $exclude = { map { $_ => 1 } @{ $_->{exclude_branches} || [] } };
        my $map_branches = $_->{map_branches} || {};
        my $private = $_->{private} || 0;
        my $alternatives = $_->{alternatives} || 0;
        if ($alternatives) {
            die 'source_lang is required' unless $alternatives->{source_lang};
            die 'alternative_lang is required' unless $alternatives->{alternative_lang};
        }
        $repo->add_source( \@sources, $prefix, $path, $exclude, $map_branches, $private, $alternatives );
    }

    bless { sources => \@sources, temp_dir => $args{temp_dir} }, $class;
}

#===================================
sub first {
#===================================
    return shift->sources->[0];
}

#===================================
sub has_changed {
#===================================
    my $self   = shift;
    my $title  = shift;
    my $branch = shift;
    my $direct_html = shift;
    # If any of the repos have changed then we'll return 1. 
    my $all_new_sub_dir = 1;
    for my $source ( $self->_sources_for_branch($branch) ) {
        my $repo_branch = $source->{map_branches}->{$branch} || $branch;
        my $has_changed = $source->{repo}->has_changed(
            $title, $repo_branch, $source->{path}, $direct_html
        );
        if ( $has_changed eq 'new_sub_dir' ) {
            # sub_dirs for new sources are special: They don't count as
            # "changed" most of the time. The idea is that if the book built
            # properly without them last time it was built with these hashes
            # then it won't need them *this* time. On the other hand, if the
            # *entire* book is new sub_dirs we'll build it because we have
            # entirely new sources. This has the advantage of rebuilding books
            # like the Kibana reference in PR builds against a new branch
            # because it is a single source book. This is nice because it gets
            # us *some* test coverage.
            next;
        }
        return 1 if $has_changed eq 'changed';
        die "Unexpected '$has_changed'" unless $has_changed eq 'not_changed';
        $all_new_sub_dir = 0;
    }
    return $all_new_sub_dir;
}

#===================================
sub mark_done {
#===================================
    my $self   = shift;
    my $title  = shift;
    my $branch = shift;
    my $direct_html = shift;
    for my $source ( $self->_sources_for_branch($branch) ) {
        my $repo_branch = $source->{map_branches}->{$branch} || $branch;
        $source->{repo}->mark_done( $title, $repo_branch, $source->{path}, $direct_html );
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
    my %roots;

    # need to handle repo name here, not in Repo
    for my $source ( $self->_sources_for_branch($branch) ) {
        my $repo   = $source->{repo};
        my $prefix = $source->{prefix};
        my $path   = $source->{path};
        my $repo_branch = $source->{map_branches}->{$branch} || $branch;

        my $source_checkout = $repo->prepare( $title, $repo_branch, $path, $checkout, $prefix );
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
        $roots{ $repo->name } = $source_checkout;
    }
    return ( $checkout, \%edit_urls, $first_path, \@alternatives, \%roots );
}

#===================================
sub _sources_for_branch {
#===================================
    my $self   = shift;
    my $branch = shift;
    return grep { !$_->{exclude}{$branch} } @{ $self->sources };
}

#===================================
sub sources { shift->{sources} }
sub temp_dir { shift->{temp_dir} }
#===================================

1;
