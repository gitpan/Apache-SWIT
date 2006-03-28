use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::Generator;
use base 'Apache::SWIT::Maker::GeneratorBase';
use File::Slurp;

sub location_section_prolog {
	my ($self, $res, $loc, $e) = @_;
	return $e->{do_not_use} ? "" : "PerlModule " . $e->{class} . "\n";
}


sub location_section_contents {
	my ($self, $res, $n, $v) = @_;
	my $t = $v->{template};
	return $t ? "\tPerlSetVar SWITTemplate \@ServerRoot\@/$t\n" : "";
}

sub httpd_conf_start {
	my ($self, $res) = @_;
	my $sc = $self->tree->{session_class};
	$res = read_file('conf/httpd.conf.in') . "\n";
	$res =~ s/\@SessionClass\@/$sc/g;
	return $res;
}

1;
