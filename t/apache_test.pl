use lib 'lib';
use Apache::SWIT::Test::Apache;
use File::Slurp;
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use Apache::SWIT::Maker::Skeleton::Startup;
use Test::TempDatabase;
use Apache::SWIT::DB::Connection;

my $test_db;
Apache::SWIT::Test::Apache::Run('extra.conf.swit', 'extra.conf.in', sub {
	mkpath(dirname($0) . "/../blib/conf");
	write_file(dirname($0) . "/../blib/conf/seal.key", "boo boo boo");
	write_file(dirname($0) . "/../blib/conf/startup.pl"
		, Apache::SWIT::Maker::Skeleton::Startup->new->get_output);
	$test_db = Test::TempDatabase->create(dbname => 'swit_test_db'
			, dbi_args => Apache::SWIT::DB::Connection->DBIArgs);
	Apache::SWIT::DB::Connection->instance($test_db->handle);
	$ENV{APACHE_SWIT_DB_NAME} = 'swit_test_db';
});
END { $test_db->destroy if $test_db; }
