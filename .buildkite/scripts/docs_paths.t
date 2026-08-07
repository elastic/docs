#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin qw($RealBin);

# Regression check for docs_paths.pl's repo-name resolution and path collection.
# Run from the repo root since docs_paths.pl defaults to ./conf.yaml.

chdir "$RealBin/../.." or die "Can't chdir to repo root: $!";

my $conf = 'conf.yaml';

sub run {
    my ($repo) = @_;
    my $out = `perl .buildkite/scripts/docs_paths.pl @{[quotemeta $repo]} $conf 2>/dev/null`;
    return ( $? >> 8, $out );
}

{
    my ( $exit, $out ) = run('kibana');
    is( $exit, 0, 'kibana: exits 0' );
    like( $out, qr{docs/}, 'kibana: includes docs/' );
    like( $out, qr{:\(glob\).*asciidoc}, 'kibana: includes a glob asciidoc pathspec' );
}

{
    my ( $exit, $out ) = run('elastic-serverless-forwarder');
    is( $exit, 0, 'elastic-serverless-forwarder: exits 0' );
    like( $out, qr{docs/en}, 'elastic-serverless-forwarder: resolves via URL basename to docs/en' );
}

{
    my ( $exit, $out ) = run('some-repo-not-in-conf-yaml');
    is( $exit, 0, 'unknown repo: exits 0' );
    is( $out, '', 'unknown repo: no doc paths' );
}

done_testing();
