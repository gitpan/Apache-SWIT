use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::Generator;
use base 'Apache::SWIT::Maker::GeneratorBase';
use File::Slurp;

sub location_section_contents {
	my ($self, $res, $n, $v) = @_;
	my $t = $v->{template} or return "";
	return "\tPerlSetVar SWITIncludePath \@ServerRoot\@\t\n"
		. "PerlSetVar SWITTemplate $t\n";
}

sub httpd_conf_start {
	my ($self, $res) = @_;
	my $sc = Apache::SWIT::Maker::Config->instance->session_class;
	$res = read_file('conf/httpd.conf.in') . "\n";
	$res =~ s/\@SessionClass\@/$sc/g;
	return $res;
}

1;
