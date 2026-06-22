#!/usr/bin/env perl
use strict;
use warnings;
use YAML qw(LoadFile);

# Usage: legacy_branches.pl <github-repo-name>
# Prints one legacy (AsciiDoc) branch per line that the given repo still carries in conf.yaml.
#
# Exit 0: repo found; list may be empty if fully migrated to docs-builder.
# Exit 2: repo not found in conf.yaml — caller should build as today (fail open).
# Exit 1: YAML parse / load error — caller should build as today (fail open).

my ($github_repo) = @ARGV
    or die "Usage: $0 <github-repo-name>\n";

# conf.yaml lives in the repo root, which is also the working directory when
# build_pr.sh runs — same assumption used by build_docs.pl (see build_docs.pl:964).
my $conf = eval { LoadFile('conf.yaml') };
if ($@) {
    warn "Failed to load conf.yaml: $@\n";
    exit 1;
}

# Build a map: GitHub repo name (URL basename minus .git) -> conf repo key.
# Sources in conf.yaml reference the conf key (e.g. "esf"), not the GitHub name
# (e.g. "elastic-serverless-forwarder"), so we need this translation.
my %github_to_key;
while ( my ( $key, $url ) = each %{ $conf->{repos} } ) {
    ( my $name = $url ) =~ s{.*/|\.git$}{}g;    # URL -> repo name (strip path and .git)
    $github_to_key{$name} = $key;
}

my $conf_key = $github_to_key{$github_repo};
unless ( defined $conf_key ) {
    exit 2;    # repo not in conf — caller builds as today
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
