use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Test::Utils;
use base 'Exporter';
use File::Slurp;

our @EXPORT = qw(ASTU_Wait ASTU_Read_Error_Log ASTU_Read_Access_Log
		ASTU_Reset_Table ASTU_Module_Dir ASTU_Clear_Error_Log);

sub ASTU_Wait {
	my $dir = shift || "";
	print STDERR "# ASTU_WAIT: $dir\n" . Carp::longmess();
	if (!defined($ENV{ASTU_WAIT})) {
		print STDERR "# No \$ENV{ASTU_WAIT} is given. Exiting ...\n";
		goto OUT;
	} elsif (!$ENV{ASTU_WAIT}) {
		print STDERR "# \$ENV{ASTU_WAIT} == 0. Continuing ...\n";
		return;
	}
	print STDERR "# Press ENTER to continue ...\n";
	readline(\*STDIN);
OUT:
	exit 1;
}

sub ASTU_Module_Dir { return "$INC[0]/../.."; }

sub ASTU_Read_Error_Log {
	return read_file(ASTU_Module_Dir() . "/t/logs/error_log");
}

sub ASTU_Read_Access_Log {
	return read_file(ASTU_Module_Dir() . "/t/logs/access_log");
}

sub ASTU_Reset_Table {
	my $t = shift;
	my $dbh = Apache::SWIT::DB::Connection->instance->db_handle;
	$dbh->do("delete from $t");
	$dbh->do("alter sequence $t\_id_seq restart with 1");
}

sub ASTU_Clear_Error_Log {
	my $ef = ASTU_Module_Dir() . "/t/logs/error_log";
	write_file($ef, "Cleared" . Carp::longmess());
}

1;
