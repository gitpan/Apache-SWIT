use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Makefile;
use base 'Apache::SWIT::Maker::Makefile';

sub _mm_install {
	my $res = shift()->MY::SUPER::install(\@_);
	my $rc = Apache::SWIT::Maker::Config->instance->root_class;
	my $cmd = "perl -I lib -M$rc\::Maker -e "
		."'$rc\::Maker->new->write_installation_content_pm'";
	$res =~ s/pure_(\w+)_install ::/pure_$1_install ::\n\t$cmd/g;
	return $res;
}

sub _mm_constants {
	return shift()->MY::SUPER::constants(\@_);
}

1;
