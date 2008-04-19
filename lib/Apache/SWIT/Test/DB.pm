use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Test::DB;
use Test::TempDatabase;
use Apache::SWIT::DB::Connection;
use Apache::SWIT::Maker::Conversions;
use Apache::SWIT::Maker::Manifest;

our $Test_DB;

sub setup {
	my ($class, $dbn, $sc, $args) = @_;
	my $nd = $ENV{APACHE_SWIT_DB_NAME};
	$ENV{APACHE_SWIT_DB_NAME} = $dbn unless $ENV{APACHE_SWIT_DB_NAME};
	conv_eval_use($sc);
	local $SIG{__DIE__} = sub {
		print STDERR "# " . Carp::longmess(@_);
		exit 1;
	};
	$Test_DB = Test::TempDatabase->create(no_drop => $nd
		, dbname => $ENV{APACHE_SWIT_DB_NAME}
		, dbi_args => ($args || Apache::SWIT::DB::Connection->DBIArgs));

	my $stop = $ENV{APACHE_SWIT_LOAD_DB} ? "echo \\\\set ON_ERROR_STOP;"
			: "";
	my $ssql = "t/conf/schema.sql";
	$ENV{APACHE_SWIT_LOAD_DB} = $ssql
		if (-f $ssql && !$nd && !$ENV{APACHE_SWIT_LOAD_DB});

	# -f option doesn't always work for large objects
	conv_silent_system("($stop cat $ENV{APACHE_SWIT_LOAD_DB})"
			. " | psql --single-transaction"
			. " -d $ENV{APACHE_SWIT_DB_NAME}")
		if ($ENV{APACHE_SWIT_LOAD_DB});
	$sc->new($Test_DB->handle)->run_updates;
	Apache::SWIT::DB::Connection->instance($Test_DB->handle);
	mkpath_write_file('t/logs/db_is_clean', "\n");
}

END { $Test_DB->destroy; }

1;
