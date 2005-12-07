=head1 NAME

Apache::SWIT - mod_perl based application server with integrated testing.

=head1 SYNOPSIS

	package MyHandler;
	use base 'Apache::SWIT';

	# overload render routine
	sub swit_render {
		my ($class, $r) = @_;
		return ('my_template.tt', { hello => 'world' });
	}

	# overload update routine, usually result of POST
	sub swit_update {
		my ($class, $r) = @_;
		# do some work ...
		# and redirect to another page
		return '/redirect/to/some/url';
	}

=head1 DISCLAIMER
	
	This is pre-alpha quality software. Please use it on your own
risk.

=head1 DESCRIPTION

This module serves as yet another mod_perl based application server.

It tries to capture several often occuring paradigms in mod_perl development.
It provides user with the tools to bootstrap a new project, write tests easily,
etc.

=head1 USAGE



=cut

use strict;
use warnings FATAL => 'all';

package Apache::SWIT;
use Template;
use Apache::Request;

our $VERSION = 0.03;

sub swit_update_i {
	my($class, $r, $session) = @_;
	my $to = $class->swit_update($r, $session);
	$r->status(302);
	$r->header_out(Location => $to);
	$session->end;
	$r->send_http_header("text/html");
	return 302;
}

sub swit_render_i {
	my($class, $r, $session) = @_;
	my ($file, $vars) = $class->swit_render($r, $session);
	my $t = Template->new({ ABSOLUTE => 1 }) or die "No template";
	die "No file" if !defined($file);

	$session->end;
	$r->send_http_header("text/html");
	my $out;
	$t->process($file, $vars, \$out)
		or die "No result for $file: " . $t->error;
	$r->print($out);
	return 200;
}

my %_handlers = (r => 'render', u => 'update');

sub handler($$) {
	my($class, $r) = @_;
	my $loc = $r->location;
	$r->uri =~ /^$loc\/(\w+)/;
	my $t = $1 or die "Unable to find request type";
	my $h = $_handlers{$t} or die "Unable to find handler for $t";
	my $f = "swit_$h\_i";
	my $session = $r->pnotes('SWITSession');
	return $class->$f(Apache::Request->new($r), $session);
}

1;

=head1 BUGS

Much needed documentation is non-existant at the moment.

=head1 AUTHOR

	Boris Sukholitko
	boriss@gmail.com

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

HTML::Tested

=cut
