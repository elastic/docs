#!/usr/bin/env perl
use strict;
use warnings;
use YAML qw(LoadFile);

# Usage: docs_paths.pl <github-repo-name> [conf.yaml]
# Prints one git-diff path per line from conf.yaml sources for the repo.
#
# Exit 0: conf.yaml was read successfully. Output is empty if the repo is not
#         in conf.yaml or has no source paths.
# Exit 1: conf.yaml couldn't be loaded (e.g. missing YAML module, parse error)
#         — caller should build as today (fail open), since we can't tell.

my ( $github_repo, $conf_path ) = @ARGV;
$conf_path //= 'conf.yaml';

die "Usage: $0 <github-repo-name> [conf.yaml]\n" unless defined $github_repo;

my $conf = eval { LoadFile($conf_path) };
if ($@) {
    warn "Failed to load $conf_path: $@\n";
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
    exit 0;    # repo not in conf — no doc paths, caller should skip
}

my %paths;
walk_entries( $conf->{contents}, $conf_key, \%paths );

print "$_\n" for sort keys %paths;
exit 0;


sub walk_entries {
    my ( $entries, $conf_key, $paths ) = @_;
    for my $entry (@$entries) {
        if ( $entry->{sections} ) {
            walk_entries( $entry->{sections}, $conf_key, $paths );
        } else {
            collect_source_paths( $entry, $conf_key, $paths );
        }
    }
}

sub collect_source_paths {
    my ( $book, $conf_key, $paths ) = @_;
    for my $source ( @{ $book->{sources} // [] } ) {
        next unless ( $source->{repo} // '' ) eq $conf_key;
        my $path = normalize_path( $source->{path} );
        $paths->{$path} = 1 if defined $path && length $path;
    }
}

sub normalize_path {
    my ($path) = @_;
    return unless defined $path;
    $path =~ s{^/}{};    # strip leading slash for git diff
    return $path;
}
