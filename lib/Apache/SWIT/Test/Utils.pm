use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Test::Utils;
use base 'Exporter';
use File::Slurp;

our @EXPORT = qw(ASTU_Wait ASTU_Read_Error_Log ASTU_Read_Access_Log
		ASTU_Reset_Table);

our $ASTU_Should_Wait = $ENV{ASTU_WAIT};
$ENV{ASTU_WAIT} = 0;

sub ASTU_Wait {
	my $dir = shift;
	unless ($ASTU_Should_Wait) {
		print STDERR "# ASTU_WAIT: no \$ENV{ASTU_WAIT} is given\n";
		return;
	}
	print STDERR "# Test is in $dir ...\nPress ENTER to continue ...\n";
	readline(\*STDIN);
}

sub ASTU_Read_Error_Log {
	return read_file($ENV{SWIT_BLIB_DIR} . "/../t/logs/error_log");
}

sub ASTU_Read_Access_Log {
	return read_file($ENV{SWIT_BLIB_DIR} . "/../t/logs/access_log");
}

sub ASTU_Reset_Table {
	my $t = shift;
	my $dbh = Apache::SWIT::DB::Connection->instance->db_handle;
	$dbh->do("delete from $t");
	$dbh->do("alter sequence $t\_id_seq restart with 1");
}

1;
