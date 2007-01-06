use strict;
use warnings FATAL => 'all';

package T::TransFailure::Root;
use base 'HTML::Tested';

package T::TransFailure;
use base 'Apache::SWIT::HTPage';
use Apache::SWIT::DB::Connection;

sub ht_swit_update {
	my $dbh = Apache::SWIT::DB::Connection->instance->db_handle;
	$dbh->do("insert into trans values(20)");
	$dbh->do("insert into trans values(1)");
	return "r";
}

1;
