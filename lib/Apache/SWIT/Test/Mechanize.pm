use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Test::Mechanize;
use base 'WWW::Mechanize';
use Apache::TestRequest;

sub get_base {
	my ($self, $loc) = @_;
	return $self->get("http://" . Apache::TestRequest::hostport() . $loc);
}

1;
