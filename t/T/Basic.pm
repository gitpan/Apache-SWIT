use strict;
use warnings FATAL => 'all';

package T::Basic;
 
sub handler ($$) {
	my($class, $r) = @_;
	$r->send_http_header("text/plain");
	print "hhhh\n$INC[0]";
	return 200;
}

1;
