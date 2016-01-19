#
#   Proc::PID::File - pidfile manager
#   Copyright (C) 2001-2003 Erick Calder
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

package Proc::PID::File;

=head1 NAME

Proc::PID::File - a module to manage process id files

=head1 SYNOPSIS

  use Proc::PID::File;
  die "Already running!" if Proc::PID::File->running();

Process that spawn child processes may want to protect
each separately by using multiple I<pidfiles>.

  my $child1 = Proc::PID::File->new(name => "lock.1");
  my $child2 = Proc::PID::File->new(name => "lock.2");

which may be checked like this:

  <do-something> if $child1->alive();

and should be released manually:

  $child1->release();

=head1 DESCRIPTION

This Perl module is useful for writers of daemons and other processes that need to tell whether they are already running, in order to prevent multiple process instances.  The module accomplishes this via *nix-style I<pidfiles>, which are files that store a process identifier.

The module provides two interfaces: 1) a simple call, and
2) an object-oriented interface

=cut

require Exporter;
@ISA = qw(Exporter);

use strict;
use vars qw($VERSION $RPM_Requires);
use Fcntl qw(:DEFAULT :flock);

$VERSION = "1.27";
$RPM_Requires = "procps";

my $RUNDIR = "/var/run";
my ($ME) = $0 =~ m|([^/]+)$|;
my $self;

# -- Simple Interface --------------------------------------------------------

=head1 Simple Interface

The simple interface consists of a call as indicated in the first example
of the B<Synopsis> section above.  This approach avoids causing race
conditions whereby one instance of a daemon could read the I<pidfile>
after a previous instance has read it but before it has had a chance
to write to it.

=head2 running [hash[-ref]]

The parameter signature for this function is identical to that of the
I<-E<gt>new()> method described below in the B<OO Interface> section of this document. The method's return value is the same as that of I<-E<gt>alive()>.

=cut

sub running {
    $self = shift->new(@_);

	local *FH;
	my $pid = $self->read(*FH);

	if ($pid && $pid != $$ && kill(0, $pid)) {
        $self->debug("running: $pid");
	    close FH;
        return $self->verify($pid) ? $pid : 0;
        }

	$self->write(*FH);
	return 0;
    }

# -- Object oriented Interface -----------------------------------------------

=head1 OO Interface

The following methods are provided:

=head2 new [hash[-ref]]

This method is used to create an instance object.  It automatically calls the I<-E<gt>file()> method described below and receives the same paramters.  For a listing of valid keys in this hash please refer to the aforementioned method documentation below.

In addition to the above, the following constitute valid keys:

=over

=item I<verify> = 1 | string

This parameter implements the second solution outlined in the WARNING section
of this document and is used to verify that an existing I<pidfile> correctly
represents a live process other than the current.  If set to a string, it will
be interpreted as a I<regular expression> and used to search within the name
of the running process.  Alternatively, a 1 may be passed: For Linux/FreeBSD,
this indicates that the value of I<$0> will be used (stripped of its full
path); for Cygwin, I<$^X> (stripped of path and extension) will be used.

If the parameter is not passed, no verification will take place.  Please
note that verification will only work for the operating systems
listed below and that the OS will be auto-sensed.  See also DEPENDENCIES
section below.

Supported platforms: Linux, FreeBSD, Cygwin

=item I<debug>

Any non-zero value turns debugging output on.  Additionally, if a string
is passed containing the character B<M>, the module name will be prefixed
to the debugging output.

=back

=cut

sub new {
	my $class = shift;
	my $self = bless({}, $class);
	%$self = &args;
	$self->file();	# init file path
	$self->{debug} ||= "";
	return $self;
	}

=head2 file [hash[-ref]]

Use this method to set the path of the I<pidfile>.  The method receives an optional hash (or hash reference) with the keys listed below, from which it makes a path of the format: F<$dir/$name.pid>.

=over

=item I<dir>

Specifies the directory to place the pid file.  If left unspecified,
defaults to F</var/run>.

=item I<name>

Indicates the name of the current process.  When not specified, defaults
to I<basename($0)>.

=back

=cut

sub file {
	my $self = shift;
	%$self = (%$self, &args);
	$self->{dir} ||= $RUNDIR;
	$self->{name} ||= $ME;
	$self->{path} = sprintf("%s/%s.pid", $self->{dir}, $self->{name});
	}

=head2 alive

Returns true when the process is already running.  Please note that this
call must be made *after* daemonisation i.e. subsequent to the call to
fork(). If the B<verify> flag was set during the instance creation, the
process id is verified, alternatively the flag may be passed directly
to this method.

=cut

sub alive {
	my $self = shift;

	my %args = &args;
	$self->{verify} = $args{verify} if $args{verify};

	my $pid = $self->read() || "";
	$self->debug("alive(): $pid");

	if ($pid && $pid != $$ && kill(0, $pid)) {
        return $self->verify($pid) ? $pid : 0;
        }

	return 0;
	}

=head2 touch

Causes for the current process id to be written to the I<pidfile>.

=cut

sub touch {
	shift->write();
	}

=head2 release

This method is used to delete the I<pidfile> and is automatically called by DESTROY method.  It should thus be unnecessary to call it directly.

=cut

sub release {
	my $self = shift;
	$self->debug("release()");
	unlink($self->{path}) || warn $!;
	}

=head2 locktime [hash[-ref]]

This method returns the I<mtime> of the I<pidfile>.

=cut

sub locktime {
    my $self = shift;
    return (stat($self->{path}))[10];
	}

# -- support functionality ---------------------------------------------------

sub verify {
    my ($self, $pid) = @_;
    return 1 unless $self->{verify};

	my $ret = 0;
    $self->debug("verify(): OS = $^O");
    if ($^O =~ /linux|freebsd|cygwin/i) {
        my $me = $self->{verify};
		if (!$me || $me eq "1") {
			$me = $ME;
			if ($^O eq "cygwin") {
				$^X =~ m|([^/]+)$|;
				($me = $1) =~ s/\.exe$//;
				}
			}
		my $cols = delete($ENV{'COLUMNS'}); # prevents `ps` from wrapping
        my @ps = split m|$/|, qx/ps -fp $pid/
            || die "ps utility not available: $!";
        s/^\s+// for @ps;   # leading spaces confuse us

		$ENV{'COLUMNS'} = $cols if defined($cols);
        no warnings;    # hate that deprecated @_ thing
        my $n = split(/\s+/, $ps[0]);
        @ps = split /\s+/, $ps[1], $n;
        $ret = $ps[$n - 1] =~ /\Q$me\E/;;
        }

	$self->debug(" - ret: [$ret]");
	$ret;
    }

# Returns the process id currently stored in the file set.  If the method
# is passed a file handle, it will return the value, leaving the file handle
# locked.  This is useful for atomic operations where the caller needs to
# write to the file after the read without allowing other dirty writes.
# 
# Please note, when passing a file handle, caller is responsible for
# closing it. Also, file handles must be passed by reference!

sub read {
	my ($self, $fh) = @_;

	sysopen $fh, $self->{path}, O_RDWR|O_CREAT
		|| die qq/Cannot open pid file "$self->{path}": $!\n/;
	flock($fh, LOCK_EX | LOCK_NB)
        || die qq/pid "$self->{path}" already locked: $!\n/;
	my ($pid) = <$fh> =~ /^(\d+)/;
	close $fh if @_ == 1;

	$self->debug("read(\"$self->{path}\") = " . ($pid || ""));
	return $pid;
	}

# Causes for the current process id to be written to the selected
# file.  If a file handle it passed, the method assumes it has already
# been opened, otherwise it opens its own. Please note that file
# handles must be passed by reference!

sub write {
	my ($self, $fh) = @_;

	$self->debug("write($$)");
	if (@_ == 1) {
		sysopen $fh, $self->{path}, O_RDWR|O_CREAT
			|| die qq/Cannot open pid file "$self->{path}": $!\n/;
		flock($fh, LOCK_EX | LOCK_NB)
        	|| die qq/pid "$self->{path}" already locked: $!\n/;
		}
	sysseek  $fh, 0, 0;
	truncate $fh, 0;
	syswrite $fh, "$$\n", length("$$\n");
	close $fh || die qq/Cannot write pid file "$self->{path}": $!\n/;
	}

sub args {
	!defined($_[0]) ? () : ref($_[0]) ? %{$_[0]} : @_;
	}

sub debug {
	my $self = shift;
	my $msg = shift || $_;

	$msg = "> Proc::PID::File - $msg"
		if $self->{debug} =~ /M/;	# prefix with module name
	print $msg
		if $self->{debug};
	}

sub DESTROY {
	my $self = shift;

    if (exists($INC{'threads.pm'})) {
        return if threads->tid() != 0;
    	}
    
	my $pid = $self->read();
	$self->release()
        if $self->{path} && $pid && $pid == $$;
	}

1;

__END__

# -- documentation -----------------------------------------------------------

=head1 AUTHOR

Erick Calder <ecalder@cpan.org>

=head1 ACKNOWLEDGEMENTS

1k thx to Steven Haryanto <steven@haryan.to> whose package (Proc::RID_File) inspired this implementation.

Our gratitude also to Alan Ferrency <alan@pair.com> for fingering the boot-up problem and suggesting possible solutions.

=head1 DEPENDENCIES

For Linux, FreeBSD and Cygwin, support of the I<verify> option requires
availability of the B<ps> utility.  For Linux/FreeBSD This is typically
found in the B<procps> package. Cygwin users need to run version 1.5.20
or later for this to work.

=head1 WARNING

This module may prevent daemons from starting at system boot time.  The problem occurs because the process id written to the I<pidfile> by an instance of the daemon may coincidentally be reused by another process after a system restart, thus making the daemon think it's already running.

Some ideas on how to fix this problem are catalogued below, but unfortunately, no platform-independent solutions have yet been gleaned.

=over

=item - leaving the I<pidfile> open for the duration of the daemon's life

=item - checking a C<ps> to make sure the pid is what one expects (current implementation)

=item - looking at /proc/$PID/stat for a process name

=item - check mtime of the pidfile versus uptime; don't trust old pidfiles

=item - try to get the script to nuke its pidfile when it exits (this is vulnerable to hardware resets and hard reboots)

=item - try to nuke the pidfile at boot time before the script runs; this solution suffers from a race condition wherein two instances read the I<pidfile> before one manages to lock it, thus allowing two instances to run simultaneously.

=back

=head1 SUPPORT

For help and thank you notes, e-mail the author directly.  To report a bug, submit a patch or add to our wishlist please visit the CPAN bug manager at: F<http://rt.cpan.org>

=head1 AVAILABILITY

The latest version of the tarball, RPM and SRPM may always be found at: F<http://perl.arix.com/>  Additionally the module is available from CPAN.

=head1 LICENCE

This utility is free and distributed under GPL, the Gnu Public License.  A copy of this license was included in a file called LICENSE. If for some reason, this file was not included, please see F<http://www.gnu.org/licenses/> to obtain a copy of this license.

$Id: File.pm,v 1.16 2004-04-08 02:27:25 ekkis Exp $
