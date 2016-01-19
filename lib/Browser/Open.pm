package Browser::Open;
our $VERSION = '0.04';



use strict;
use warnings;
use Carp;
use File::Spec::Functions qw( catfile );

use parent 'Exporter';

@Browser::Open::EXPORT_OK = qw(
  open_browser
  open_browser_cmd
  open_browser_cmd_all
);

my @known_commands = (
  ['', $ENV{BROWSER}],
  ['darwin',  '/usr/bin/open', 1],
  ['cygwin',  'start'],
  ['MSWin32', 'start', undef, 1],
  ['solaris', 'xdg-open'],
  ['solaris', 'firefox'],
  ['linux',   'sensible-browser'],
  ['linux',   'xdg-open'],
  ['linux',   'x-www-browser'],
  ['linux',   'www-browser'],
  ['linux',   'htmlview'],
  ['linux',   'gnome-open'],
  ['linux',   'gnome-moz-remote'],
  ['linux',   'kfmclient'],
  ['linux',   'exo-open'],
  ['linux',   'firefox'],
  ['linux',   'seamonkey'],
  ['linux',   'opera'],
  ['linux',   'mozilla'],
  ['linux',   'iceweasel'],
  ['linux',   'netscape'],
  ['linux',   'galeon'],
  ['linux',   'opera'],
  ['linux',   'w3m'],
  ['linux',   'lynx'],
  ['freebsd', 'xdg-open'],
  ['freebsd', 'gnome-open'],
  ['freebsd', 'gnome-moz-remote'],
  ['freebsd', 'kfmclient'],
  ['freebsd', 'exo-open'],
  ['freebsd', 'firefox'],
  ['freebsd', 'seamonkey'],
  ['freebsd', 'opera'],
  ['freebsd', 'mozilla'],
  ['freebsd', 'netscape'],
  ['freebsd', 'galeon'],
  ['freebsd', 'opera'],
  ['freebsd', 'w3m'],
  ['freebsd', 'lynx'],
  ['',        'open'],
  ['',        'start'],
);

##################################

sub open_browser {
  my ($url, $all) = @_;
  croak('Missing required parameter $url, ') unless $url;

  my $cmd = $all ? open_browser_cmd_all() : open_browser_cmd();
  return unless $cmd;

  return system($cmd, $url);
}

sub open_browser_cmd {
  return _check_all_cmds($^O);
}

sub open_browser_cmd_all {
  return _check_all_cmds('');
}


##################################

sub _check_all_cmds {
  my ($filter) = @_;

  foreach my $spec (@known_commands) {
    my ($osname, $cmd, $exact, $no_search) = @$spec;
    next unless $cmd;
    next if $osname && $filter && $osname ne $filter;
    next if $no_search && !$filter && $osname ne $^O;

    return $cmd if $exact && -x $cmd;
    return $cmd if $no_search;
    $cmd = _search_in_path($cmd);
    return $cmd if $cmd;
  }
  return;
}

sub _search_in_path {
  my $cmd = shift;

  for my $path (split(/:/, $ENV{PATH})) {
    next unless $path;
    my $file = catfile($path, $cmd);
    return $file if -x $file;
  }
  return;
}


1;
__END__

=head1 NAME

Browser::Open - open a browser in a given URL


=head1 VERSION

version 0.03

=head1 SYNOPSIS

    use Browser::Open qw( open_browser );
    
    ### Try commands specific to the current Operating System
    my $ok = open_browser($url);
    # ! defined($ok): no recognized command found
    # $ok == 0: command found and executed
    # $ok != 0: command found, error while executing
    
    ### Try all known commands
    my $ok = open_browser($url, 1);


=head1 DESCRIPTION

The functions optionaly exported by this module allows you to open URLs
in the user browser.

A set of known commands per OS-name is tested for presence, and the
first one found is executed. With an optional parameter, all known
commands are checked.

The L<"open_browser"> uses the C<system()> function to execute the
command. If you want more control, you can get the command with the
L<"open_browser_cmd"> or L<"open_browser_cmd_all"> functions and then
use whatever method you want to execute it.


=head1 API

All functions are B<not> exported by default. You must ask for them
explicitly.


=head2 open_browser

    my $ok = open_browser($url, $all);

Find an appropriate command and executes it with your C<$url>. If
C<$all> is false, the default, only commands that match the current OS
will be tested. If true, all known commands will be tested.

If no command was found, returns C<undef>.

If a command is found, returns the exit code of the execution attempt, 0
for success. See the C<system()> for more information about this
exit code.

If no C<$url> is given, an exception will be thrown:
C<< Missing required parameter $url >>.


=head2 open_browser_cmd

    my $cmd = open_browser_cmd();

Returns the best command found to open a URL on your system.

If no command was found, returns C<undef>.


=head2 open_browser_cmd_all

    my $cmd = open_browser_cmd_all();

Returns the first command found to open a URL.

If no command was found, returns C<undef>.


=head1 AUTHOR

Pedro Melo, C<< <melo at cpan.org> >>


=head1 COPYRIGHT & LICENSE

Copyright 2009 Pedro Melo.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut