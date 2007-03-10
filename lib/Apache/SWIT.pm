=head1 NAME

Apache::SWIT - mod_perl based application server with integrated testing.

=head1 SYNOPSIS

	package MyHandler;
	use base 'Apache::SWIT';

	# overload render routine
	sub swit_render {
		my ($class, $r) = @_;
		return ({ hello => 'world' }, 'my_template.tt');
		# or return { hello => 'world' }; to rely on swit.yaml
		# based generation
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

our $VERSION = 0.24;

sub swit_startup {}

sub swit_send_http_header {
	my ($class, $r) = @_;
	$r->pnotes('SWITSession')->end;
	$r->send_http_header("text/html; charset=utf-8");
}

sub swit_update_finish {
	my ($class, $r, $to) = @_;
	my $s = ref($to) ? $to->[0] : 302;
	$r->status($s);
	$r->header_out(Location => $to) unless ref($to);
	$class->swit_send_http_header($r);
	$r->print($to->[1]) if ref($to);
	return $s;
}

sub swit_update_handler($$) {
	my($class, $r) = @_;
	my $ar = Apache::Request->new($r);
	my $to = $class->swit_update($ar);
	return $class->swit_update_finish($ar, $to);
}

sub swit_render_handler($$) {
	my($class, $r) = @_;
	$r->pnotes('SWITTemplate', $r->dir_config('SWITTemplate'));
	my $vars = $class->swit_render(Apache::Request->new($r));
	my $t = Template->new({ ABSOLUTE => 1 }) or die "No template";
	my $file = $r->pnotes('SWITTemplate') or die "No template file";
	$class->swit_send_http_header($r);
	my $out;
	$t->process($file, $vars, \$out)
		or die "No result for $file: " . $t->error;
	$r->print($out);
	return 200;
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
