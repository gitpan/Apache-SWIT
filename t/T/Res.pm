use strict;
use warnings FATAL => 'all';

package T::Res;
use base 'Apache::SWIT';

sub swit_render {
	my ($class, $r) = @_;
	return ($r->server_root_relative('templates/res.tt'), { 
			res => $r->param('res') });
}

1;
