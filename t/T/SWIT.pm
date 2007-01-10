use strict;
use warnings FATAL => 'all';

package T::SWIT;
use base 'Apache::SWIT';
use File::Slurp;

sub swit_render {
	my ($class, $r) = @_;
	$r->pnotes('SWITTemplate',  
			$r->server_root_relative('templates/test.tt'));
	return { hello => 'world' };
}

sub swit_update {
	my ($class, $r) = @_;
	my $f = $r->param('file') or die "No file given";
	if ($f =~ /RESPOND/) {
		return [ 200, 'This is RESPONSE' ];
	} else {
		write_file($f, $r->param('but') || '');
	}
	return '/test/res/r?res=hhhh';
}

1;
