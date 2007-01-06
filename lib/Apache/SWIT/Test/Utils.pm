use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Test::Utils;
use base 'Exporter';

our @EXPORT = qw(ASTU_Wait);

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

1;
