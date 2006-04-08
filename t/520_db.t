use strict;
use warnings FATAL => 'all';

use Test::More tests => 7;
use Test::TempDatabase;
Test::TempDatabase->become_postgres_user;

BEGIN { use_ok('Apache::SWIT::Test::ModuleTester'); }

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
chdir $mt->root_dir;
$mt->make_swit_project;
ok(-f 'LICENSE');
ok(-f 'lib/TTT/DB/Schema.pm');
ok(-f 't/T/TempDB.pm');

Apache::SWIT::Maker->new->write_pm_file("TTT::DB::C", <<ENDM);
use base 'TTT::DB::Base';
__PACKAGE__->table('ttt_table');
__PACKAGE__->sequence('ttt_table_id_seq');
__PACKAGE__->columns(Essential => qw(id a));

__PACKAGE__->db_Main->do('select * from ttt_table');
ENDM

$mt->replace_in_file('t/dual/001_load.t', '=> 3', '=> 6');
$mt->replace_in_file('t/dual/001_load.t', '\};', 
	"\n\tuse_ok('TTT::DB::Connection'); };");
$mt->insert_into_schema_pm('\$dbh->do("create table ttt_table ('
	. 'id serial primary key, a text)")');
$mt->replace_in_file('t/dual/001_load.t', "\\};\\\n", <<ENDM);
};
TTT::DB::Connection->instance->db_handle->do(
		"insert into ttt_table (a) values ('aaa')");
ENDM

$mt->replace_in_file('t/dual/001_load.t', "''", <<ENDM);
'aaa'
ENDM

Apache::SWIT::Maker::wf('>t/dual/001_load.t', <<ENDM);
isa_ok(\$t->session, 'TTT::Session');
is(\$Class::DBI::Weaken_Is_Available, 0);
ENDM

Apache::SWIT::Maker::wf('>t/010_db.t', <<ENDM);
use TTT::DB::C;
TTT::DB::C->create({ a => 'ccc' });
ENDM

$mt->replace_in_file('lib/TTT/UI/Index.pm', "return \\\$", <<ENDM);
use TTT::DB::Connection;
my \$arr = TTT::DB::Connection->instance->db_handle->selectcol_arrayref(
		"select a from ttt_table");
\$root->first(\$arr->[0]);
use TTT::DB::C;
TTT::DB::C->create({ a => 'bbb' });
return \$
ENDM

my $tres = join('', `perl Makefile.PL && make disttest 2>&1`);
like($tres, qr/success/);
unlike($tres, qr/Fail/); # or readline(\*STDIN);
is_deeply([ `psql -l |grep ttt_test_db` ], []) or diag($tres);

chdir '/'
