use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Test::Request;
use base 'HTML::Tested::Test::Request';

sub unparsed_uri { return shift()->uri; }
sub pool { return shift; }
sub prev { return shift; }

sub cleanup_register {
	my ($self, $func) = @_;
	push @{ $self->{cleanups} }, $func;
}

sub run_cleanups {
	my $self = shift;
	$_->() for @{ $self->{cleanups} };
}

sub get_server_port { return 80; }
sub get_server_name { return "some.host"; }

1;
