use strict;
use warnings FATAL => 'all';

package T::SWIT;
use base 'Apache::SWIT';

sub swit_render {
	my ($class, $r) = @_;
	$r->pnotes('SWITTemplate',  
			$r->server_root_relative('templates/test.tt'));
	return { hello => 'world' };
}

sub swit_update {
	my ($class, $r) = @_;
	my $f = $r->param('file') or die "No file given";
	open(my $fh, ">$f") or die "Unable to open $f";
	close $fh;
	return '/test/res/r?res=hhhh';
}

1;
