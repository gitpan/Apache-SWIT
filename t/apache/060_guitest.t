use strict;
use warnings FATAL => 'all';

use Test::More tests => 8;
use Apache::SWIT::Test::Utils;
use Encode;

BEGIN { use_ok('Apache::SWIT::Test');
	Apache::SWIT::Test->do_startup("AA_ROOT");
	use_ok('T::DBPage');
}

Apache::SWIT::Test->make_aliases(db_page => 'T::DBPage');
is($ENV{SWIT_HAS_APACHE}, 1);


my $t = Apache::SWIT::Test->new_guitest;
$t->ok_ht_db_page_r(base_url => '/test/db_page/r', ht => {
	val => ''
});

$t->mech->run_js("return form_submit()");
is_deeply($t->mech->console_messages, []);

my $b = 'баба';
$t->content_like(qr/$b/);

my $dbh = Apache::SWIT::DB::Connection->instance->db_handle;
is_deeply($dbh->selectcol_arrayref("select val from dbp"), [ 'баба' ]);

ASTU_Reset_Table("dbp");

is_deeply($dbh->selectcol_arrayref("select * from dbp"), []);
