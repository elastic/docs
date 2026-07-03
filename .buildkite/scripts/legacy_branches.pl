#!/usr/bin/env perl
use strict;
use warnings;
use YAML qw(LoadFile);

# Usage: legacy_branches.pl <github-repo-name>
# Prints one legacy (AsciiDoc) branch per line that the given repo still carries in conf.yaml.
#
# Exit 0: conf.yaml was read successfully. The list is empty if the repo is
#         fully migrated to docs-builder or isn't in conf.yaml at all — either
#         way it has no legacy branches, so the caller should skip the build.
# Exit 1: conf.yaml couldn't be loaded (e.g. missing YAML module, parse error)
#         — caller should build as today (fail open), since we can't tell.

my ($github_repo) = @ARGV
    or die "Usage: $0 <github-repo-name>\n";

# conf.yaml lives in the repo root, which is also the working directory when
# build_pr.sh runs — same assumption used by build_docs.pl (see build_docs.pl:964).
my $conf = eval { LoadFile('conf.yaml') };
if ($@) {
    warn "Failed to load conf.yaml: $@\n";
    exit 1;
}

# Sources in conf.yaml reference the conf key (e.g. "esf"), which for most repos
# is already the GitHub repo name but for some (e.g. "elastic-serverless-forwarder")
# differs from it. Try the GitHub name as a conf key directly first, then fall back
# to matching it against each repo's URL basename.
my $conf_key = exists $conf->{repos}{$github_repo} ? $github_repo : undef;
unless ( defined $conf_key ) {
    while ( my ( $key, $url ) = each %{ $conf->{repos} } ) {
        ( my $name = $url ) =~ s{.*/|\.git$}{}g;    # URL -> repo name (strip path and .git)
        if ( $name eq $github_repo ) {
            $conf_key = $key;
            last;
        }
    }
}

unless ( defined $conf_key ) {
    exit 0;    # repo not in conf — no legacy branches, caller should skip
}

# Walk conf.yaml contents and collect every git branch for which this repo still
# appears as a source, using the same branch-resolution rules as the build itself
# (ES::Book:104-109 + ES::BranchTracker:63):
#   - git branch = LHS of each branches entry (scalar or single-key hash)
#   - map_branches{book_branch} applied to get the actual git branch in the source repo
#   - branches in exclude_branches skipped
my %branches;
walk_entries( $conf->{contents}, $conf_key, \%branches );

print "$_\n" for sort keys %branches;
exit 0;


sub walk_entries {
    my ( $entries, $conf_key, $branches ) = @_;
    for my $entry (@$entries) {
        if ( $entry->{sections} ) {
            walk_entries( $entry->{sections}, $conf_key, $branches );
        } else {
            collect_book_branches( $entry, $conf_key, $branches );
        }
    }
}

sub collect_book_branches {
    my ( $book, $conf_key, $branches ) = @_;
    my $branch_list = $book->{branches} or return;
    my $sources     = $book->{sources}  or return;

    my @matching = grep { ( $_->{repo} // '' ) eq $conf_key } @$sources;
    return unless @matching;

    for my $source (@matching) {
        my $map  = $source->{map_branches}    // {};
        my %excl = map { $_ => 1 } @{ $source->{exclude_branches} // [] };

        for my $entry (@$branch_list) {
            # Each entry is a scalar or a single-key hash { book_branch => display_title }
            my ($branch) = ref $entry eq 'HASH' ? keys %$entry : ($entry);
            next if $excl{$branch};
            $branches->{ $map->{$branch} // $branch } = 1;
        }
    }
}
