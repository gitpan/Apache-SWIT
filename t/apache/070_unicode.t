use strict;
use warnings FATAL => 'all';

use Test::More tests => 6;
use Apache::SWIT::Test::Utils;
use Encode;

BEGIN { use_ok('Apache::SWIT::Test');
	Apache::SWIT::Test->do_startup("AA_ROOT");
	use_ok('T::DBPage');
}

Apache::SWIT::Test->make_aliases(db_page => 'T::DBPage');
is($ENV{SWIT_HAS_APACHE}, 1);


my $t = Apache::SWIT::Test->new;
$t->ok_ht_db_page_r(base_url => '/test/db_page/r', ht => {
	HT_SEALED_id => '', val => '',
});

$t->ht_db_page_u(ht => { val => 'дед' });
$t->ok_ht_db_page_r(ht => {
	HT_SEALED_id => '1', val => 'дед',
});

my $dbh = Apache::SWIT::DB::Connection->instance->db_handle;
is_deeply($dbh->selectcol_arrayref("select val from dbp"), [ 'дед' ]);
ASTU_Reset_Table("dbp");
