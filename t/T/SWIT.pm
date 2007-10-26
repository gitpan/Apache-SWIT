use strict;
use warnings FATAL => 'all';

package T::SWIT;
use base 'Apache::SWIT';
use File::Slurp;
use Carp;
use File::Basename qw(dirname);

sub swit_startup {
	append_file("/tmp/swit_startup_test", sprintf("%d %s %s\n"
			, $$, $_[0], (caller)[1]));
}

sub swit_render {
	my ($class, $r) = @_;
	my $f = dirname($INC{'T/SWIT.pm'}) . "/../templates/test.tt";
	$r->pnotes('SWITTemplate', $f);
	return { hello => 'world' };
}

sub swit_update {
	my ($class, $r) = @_;
	my $f = $r->param('file') or die "No file given";
	if ($f =~ /RESPOND/) {
		return [ Apache2::Const::OK, 'This is RESPONSE' ];
	} elsif ($f =~ /CTYPE/) {
		return [ Apache2::Const::OK, undef, 'text/plain' ];
	} else {
		write_file($f, $r->param('but') || '');
	}
	return '/test/res/r?res=hhhh';
}

sub ct_handler($$) {
	my ($class, $r) = @_;
	$class->swit_send_http_header($r, "text/plain");
	return Apache2::Const::OK;
}

1;
