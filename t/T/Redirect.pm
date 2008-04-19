use strict;
use warnings FATAL => 'all';

package T::Redirect;
use base 'Apache::SWIT';

sub swit_render {
	my ($class, $r) = @_;
	return [ INTERNAL => $r->param('internal') ] if $r->param('internal');
	return "../swit/r";
}

1;
