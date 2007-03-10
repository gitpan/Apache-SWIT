use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Subsystem::Generator;
use base 'Apache::SWIT::Maker::GeneratorBase';
use File::Slurp;
use Apache::SWIT::Maker::Manifest;

sub dump_page_entry {
	my ($self, $res, $v) = @_;
	my $rc = Apache::SWIT::Maker::Config->instance->root_class;
	my $tt_file = $v->{entry_points}->{r}->{template};
	$v->{file} = read_file($tt_file);
	$tt_file =~ s#^templates/##;
	$v->{entry_points}->{r}->{template} = $tt_file;
	return $v;
}

sub install_page_entry {
	my ($self, $res, $v, $module) = @_;
	my $lcm = lc($module);
	my $tt_file = $v->{entry_points}->{r}->{template} =
		"templates/$lcm/" . $v->{entry_points}->{r}->{template};
	my $rc = Apache::SWIT::Maker::Config->instance->root_class;
	swmani_write_file($tt_file, $v->{file});
	delete $v->{file};
	return $v;
}

sub httpd_conf_start {
	my ($self, $res) = @_;
	my $sc = Apache::SWIT::Maker::Config->instance->session_class;
	$res =~ s/$sc/T::$sc/g;
	return $res;
}

1;
