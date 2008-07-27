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
	
This is pre-alpha quality software. Please use it on your own risk.

=head1 DESCRIPTION

This module serves as yet another mod_perl based application server.

It tries to capture several often occuring paradigms in mod_perl development.
It provides user with the tools to bootstrap a new project, write tests easily,
etc.

=head1 METHODS

=cut

use strict;
use warnings FATAL => 'all';

package Apache::SWIT;
use Template;
use Carp;
use Data::Dumper;

our $VERSION = 0.36;

sub swit_startup {}

=head2 $class->swit_send_http_header($r, $ct)

Sends HTTP default headers: session cookie and content type. C<$r> is apache
request and C<$ct> is optional content type (defaults to
C<text/html; charset=utf-8>.

=cut
sub swit_send_http_header {
	my ($class, $r, $ct) = @_;
	$r->pnotes('SWITSession')->end;
	$r->pnotes('SWITSession', undef);
	$r->content_type($ct || "text/html; charset=utf-8");
}

=head2 $class->swit_die($msg, $r, @data_to_dump)

Dies with C<$msg> using Carp::confess and dumps request C<$r> and
C<@data_to_dump> with Data::Dumper.

=cut
sub swit_die {
	my ($class, $msg, $r, @more) = @_;
	confess "$msg with request:\n" . $r->as_string . "and more:\n"
			. join("\n", map { Dumper($_) } @more);
}

sub _raw_respond {
	my ($class, $r, $to) = @_;
	my $s = ref($to) ? $to->[0] : Apache2::Const::REDIRECT();
	if ($s eq 'INTERNAL') {
		$r->internal_redirect($r->uri . "/../" . $to->[1]);
		return Apache2::Const::OK();
	} elsif ($s eq 'SUBREQUEST') {
		my $new_r = $r->lookup_uri($r->uri . "/../" . $to->[1]);
		$new_r->pnotes("PrevRequestOpaque", $to->[2]);
		$class->swit_send_http_header($r);
		return $new_r->run;
	}
	$r->headers_out->add(Location => $to) unless ref($to);
	$class->swit_send_http_header($r, ref($to) ? $to->[2] : undef);
	$r->print($to->[1]) if (ref($to) && defined($to->[1]));
	return $s;
}

=head2 $class->swit_update_handler($class, $r)

Entry point for an update handler. Calls $class->swit_update($apr) function with
C<Apache2::Request> parameter. The result of C<swit_update> henceforth is called
C<$to> is passed down.

If C<$to> is regular string then 302 status is produced with Location equal to
C<$to>.

If C<$to> is array reference and first item is a number then the status with
C<$to->[0]> is produced and $to->[1] is returned as response body. $to->[2]
may by used as content type.

I.e. [ 200, "Hello", "text/plain" ] will respond with C<200 OK> status and
C<Hello> as a body with C<text/plain> as content type.

The first item can also be C<INTERNAL> magic string. In that case internal
redirect to the second array item is produced.

Of C<$to> parameters only $to->[0] is mandatory.

=cut
sub swit_update_handler($$) {
	my($class, $r) = @_;
	my $ar = Apache2::Request->new($r);
	my $to = $class->swit_update($ar);
	return $class->_raw_respond($ar, $to);
}

sub swit_template_config {
	my ($class, $r) = @_;
	return { ABSOLUTE => 1
			, INCLUDE_PATH => $r->dir_config('SWITIncludePath')
			, VARIABLES => { request => $r } };
}

sub swit_render_handler($$) {
	my ($class, $r) = @_;
	$r->pnotes('SWITTemplate', $r->dir_config('SWITTemplate'));
	my $ar = Apache2::Request->new($r);
	my $vars = $class->swit_render($ar);
	return $class->_raw_respond($ar, $vars) if (ref($vars) ne 'HASH');

	my $t = Template->new($class->swit_template_config($r))
			or confess "Unable to create template object";
	my $file = $r->pnotes('SWITTemplate') or confess "No template file";
	my $out;
	$t->process($file, $vars, \$out)
		or $class->swit_die("No result for $file\: " . $t->error, $r);
	$class->swit_send_http_header($r);
	$r->print($out);
	return Apache2::Const::OK();
}

sub swit_schedule {
	my ($class, $r, $worker, @msgs) = @_;
	my $dbh = Apache::SWIT::DB::Connection->instance->db_handle;
	$worker->enqueue($dbh, $_) for @msgs;
	$r->pool->cleanup_register(sub {
		$worker->new->run($dbh);
	});
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
