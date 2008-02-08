use strict;
use warnings FATAL => 'all';

use Test::More tests => 9;
use Test::TempDatabase;

BEGIN { use_ok('Apache::SWIT::DB::Connection'); }

$ENV{APACHE_SWIT_DB_NAME} = 'as_200_test_db';
my $test_db = Test::TempDatabase->create(
			dbname => 'as_200_test_db',
                        dbi_args => Apache::SWIT::DB::Connection->DBIArgs);
$test_db->handle->do("CREATE TABLE foo (bar text)");
$test_db->handle->do("INSERT INTO foo VALUES('a')");

my $arr = Apache::SWIT::DB::Connection->instance($test_db->handle)
		->db_handle->selectall_arrayref("SELECT * FROM foo");
is($arr->[0]->[0], 'a');
is(Apache::SWIT::DB::Connection->instance->db_handle, $test_db->handle);

Apache::SWIT::DB::Connection->Instance(undef);
$arr = Apache::SWIT::DB::Connection->instance->db_handle->selectall_arrayref(
		"SELECT * FROM foo");
is($arr->[0]->[0], 'a');
isnt(Apache::SWIT::DB::Connection->instance->db_handle, $test_db->handle);

my $pid = fork();
if ($pid) {
	waitpid($pid, 0);
} else {
	Apache::SWIT::DB::Connection->instance->db_handle->do(
			"INSERT INTO foo VALUES ('b')");
	exit;
}

$arr = Apache::SWIT::DB::Connection->instance->db_handle->selectall_arrayref(
		"SELECT * FROM foo ORDER BY bar");
is($arr->[0]->[0], 'a');
is($arr->[1]->[0], 'b');

eval { Apache::SWIT::DB::Connection->instance->db_handle->do("select * from c");
};
like($@, qr/200_db/);

Apache::SWIT::DB::Connection->Instance(undef);
$ENV{APACHE_SWIT_DB_USER} = 'djj';
eval { Apache::SWIT::DB::Connection->connect };
like($@, qr/failed/);
