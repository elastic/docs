#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin qw($RealBin);

# Regression check for legacy_branches.pl's repo-name resolution: it must
# handle both a GitHub repo name that already matches a conf.yaml key
# directly (e.g. "esf" itself) and one that only matches via a source repo's
# URL basename (e.g. "elastic-serverless-forwarder" -> "esf"). Run from the
# repo root since legacy_branches.pl reads ./conf.yaml relative to cwd.

chdir "$RealBin/../.." or die "Can't chdir to repo root: $!";

sub run {
    my ($repo) = @_;
    my $out = `perl .buildkite/scripts/legacy_branches.pl @{[quotemeta $repo]} 2>/dev/null`;
    return ( $? >> 8, $out );
}

for my $repo (qw(kibana-cn swiftype esf elastic-serverless-forwarder)) {
    my ( $exit, $out ) = run($repo);
    is( $exit, 0, "$repo: exits 0" );
    isnt( $out, '', "$repo: has at least one legacy branch (conf key resolved)" );
}

{
    my ( $exit, $out ) = run('kibana');
    is( $exit, 0, 'kibana: exits 0' );
    isnt( $out, '', 'kibana: has at least one legacy branch' );
    like( $out, qr{^8\.19$}m, 'kibana: includes 8.19 legacy branch' );
    unlike( $out, qr{^9\.}m, 'kibana: has no 9.x legacy branches' );
}

my ( $exit, $out ) = run('some-repo-not-in-conf-yaml');
is( $exit, 0, 'unknown repo: exits 0' );
is( $out, '', 'unknown repo: no legacy branches' );

done_testing();
