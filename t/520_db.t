use strict;
use warnings FATAL => 'all';

use Test::More tests => 7;
use File::Temp qw(tempdir);

BEGIN { use_ok('Apache::SWIT::Test::ModuleTester'); }

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
my $td = $mt->root_dir;

chdir $td;
`modulemaker -I -n TTT`;
ok(-f './TTT/LICENSE');
chdir 'TTT';

Apache::SWIT::Maker->new->write_initial_files();
ok(-f 'lib/TTT/DB/Schema.pm');
ok(-f 't/T/TempDB.pm');

$mt->replace_in_file('t/dual/001_load.t', '2', '4');
$mt->replace_in_file('t/dual/001_load.t', '\); \}', 
	");\n\tuse_ok('TTT::DB::Connection'); }");
$mt->insert_into_schema_pm('\$dbh->do("create table ttt_table (a text)")');
$mt->replace_in_file('t/dual/001_load.t', "\\}\\\n", <<ENDM);
}
TTT::DB::Connection->instance->db_handle->do(
		"insert into ttt_table values ('aaa')");
ENDM

$mt->replace_in_file('t/dual/001_load.t', "''", <<ENDM);
'aaa'
ENDM

Apache::SWIT::Maker::wf('>t/dual/001_load.t', <<ENDM);
isa_ok(\$t->session, 'TTT::Session');
ENDM

$mt->replace_in_file('lib/TTT/UI/Index.pm', "return \\\$", <<ENDM);
use TTT::DB::Connection;
my \$arr = TTT::DB::Connection->instance->db_handle->selectcol_arrayref(
		"select a from ttt_table");
\$root->first(\$arr->[0]);
return \$
ENDM

my $tres = join('', `perl Makefile.PL && make disttest 2>&1`);
like($tres, qr/success/);
unlike($tres, qr/Fail/);
is_deeply([ `psql -l |grep ttt_test_db` ], []) or diag($tres);

#diag($td);
#readline(\*STDIN);
chdir '/'
