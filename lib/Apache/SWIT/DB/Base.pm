use strict;
use warnings FATAL => 'all';

package Apache::SWIT::DB::Base;
use base 'Class::DBI::Pg';
use Apache::SWIT::DB::Connection;

$Class::DBI::Weaken_Is_Available = 0;
sub db_Main {
	return Apache::SWIT::DB::Connection->instance->db_handle;
}

1;
