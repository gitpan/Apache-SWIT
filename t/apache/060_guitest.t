use strict;
use warnings FATAL => 'all';

use Test::More tests => 11;
use Apache::SWIT::Test::Utils;
use Encode;

BEGIN { use_ok('T::Test');
	;
	use_ok('T::DBPage');
}

T::Test->make_aliases(db_page => 'T::DBPage');
is($ENV{SWIT_HAS_APACHE}, 1);


my $t = T::Test->new_guitest;
is($ENV{MOZ_NO_REMOTE}, 1); # or else there are coredumps sometimes
$t->ok_ht_db_page_r(base_url => '/test/db_page/r', ht => {
	val => ''
});

$t->mech->run_js("return form_submit()");
is_deeply($t->mech->console_messages, []);

my $b = 'баба';
$t->content_like(qr/$b/);

my $dbh = Apache::SWIT::DB::Connection->instance->db_handle;
{
use utf8;
is_deeply($dbh->selectcol_arrayref("select val from dbp"), [ 'баба' ]);
};

ASTU_Reset_Table("dbp");

is_deeply($dbh->selectcol_arrayref("select * from dbp"), []);

$t->ok_ht_db_page_r(base_url => '/test/db_page/r', ht => {
	val => ''
});

$t->ht_db_page_u(ht => { val => 'hoho' });
$t->ok_ht_db_page_r(ht => { val => 'hoho', HT_SEALED_id => 1 });

ASTU_Reset_Table("dbp");
