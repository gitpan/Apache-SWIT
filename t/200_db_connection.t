use strict;
use warnings FATAL => 'all';

use Test::More tests => 7;
use Test::TempDatabase;

BEGIN { use_ok('Apache::SWIT::DB::Connection'); }

package TConn;
use base 'Apache::SWIT::DB::Connection';
__PACKAGE__->AppName('AS_TEST');

package main;

$ENV{AS_TEST_DB_NAME} = 'as_200_test_db';
my $test_db = Test::TempDatabase->create(
			dbname => 'as_200_test_db',
                        dbi_args => TConn->DBIArgs);
$test_db->handle->do("CREATE TABLE foo (bar text)");
$test_db->handle->do("INSERT INTO foo VALUES('a')");

my $arr = TConn->instance($test_db->handle)
		->db_handle->selectall_arrayref("SELECT * FROM foo");
is($arr->[0]->[0], 'a');
is(TConn->instance->db_handle, $test_db->handle);

TConn->Instance(undef);
$arr = TConn->instance->db_handle->selectall_arrayref("SELECT * FROM foo");
is($arr->[0]->[0], 'a');
isnt(TConn->instance->db_handle, $test_db->handle);

my $pid = fork();
if ($pid) {
	waitpid($pid, 0);
} else {
	TConn->instance->db_handle->do("INSERT INTO foo VALUES ('b')");
	exit;
}

$arr = TConn->instance->db_handle->selectall_arrayref(
		"SELECT * FROM foo ORDER BY bar");
is($arr->[0]->[0], 'a');
is($arr->[1]->[0], 'b');

TConn->Instance(undef);
