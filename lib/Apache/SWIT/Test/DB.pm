use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Test::DB;
use Test::TempDatabase;
use Apache::SWIT::DB::Connection;
use Apache::SWIT::Maker::Conversions;

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
		, dbname => $ENV{APACHE_SWIT_DB_NAME}, schema => $sc
		, dbi_args => ($args || Apache::SWIT::DB::Connection->DBIArgs));
	Apache::SWIT::DB::Connection->instance($Test_DB->handle);
}

END { $Test_DB->destroy; }

1;
