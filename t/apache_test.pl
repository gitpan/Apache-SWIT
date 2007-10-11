use lib 'lib';
use Apache::SWIT::Test::Apache;
use File::Slurp;
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use Apache::SWIT::Maker::Skeleton::Startup;
use Test::TempDatabase;
use Apache::SWIT::DB::Connection;
use Cwd qw(abs_path);

my $test_db;
unlink("/tmp/swit_startup_test");
unless ($<) {
	my $chmod = "chmod -R a+rw " . abs_path(dirname($0)) . "/../";
	print STDERR "# Running as root. Having no other choice but: $chmod\n";
	`$chmod`;
	Test::TempDatabase->become_postgres_user;
}

my $d = abs_path(dirname($0));
$ENV{SWIT_BLIB_DIR} = "$d/../blib";
Apache::SWIT::Test::Apache->swit_run('extra.conf.swit', 'extra.conf.in', sub {
	symlink("$d/conf", "$d/../blib/conf");
	write_file("$d/conf/seal.key", "boo boo boo");
	write_file("$d/conf/startup.pl"
		, Apache::SWIT::Maker::Skeleton::Startup->new->get_output);
	$test_db = Test::TempDatabase->create(dbname => 'swit_test_db'
			, dbi_args => Apache::SWIT::DB::Connection->DBIArgs);
	Apache::SWIT::DB::Connection->instance($test_db->handle);
	$ENV{APACHE_SWIT_DB_NAME} = 'swit_test_db';

	my $dbh = Apache::SWIT::DB::Connection->instance->db_handle;
	$dbh->do("set client_min_messages to fatal");
	$dbh->do("create table dbp (id serial primary key, val text not null)");
	$dbh->do("create table upt (id serial primary key
			, loid oid unique not null)");
});
unlink("/tmp/swit_startup_test");
END { $test_db->destroy if $test_db; }
