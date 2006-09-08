use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::Makefile;
use base 'Class::Accessor';
use File::Slurp;
use ExtUtils::MakeMaker;
use ExtUtils::Manifest;
use YAML;
use File::Path qw(mkpath);
use Cwd qw(abs_path);
use ExtUtils::Install;
use Apache::SWIT::Maker::Config;
use Apache::SWIT::Maker::Conversions;

__PACKAGE__->mk_accessors('overrides', 'blib_filter', 'no_swit_overrides');

sub Args {
	my $s = read_file('Makefile.PL');
	my ($args) = ($s =~ /(\([^;]+)/);
	return $args;
}

sub get_makefile_rules {
	my $rules = YAML::LoadFile('conf/makefile_rules.yaml')
		or die "No makefile rules found";
	my $res = "";
	for my $r (@$rules) {
		$res .= join(' ',  @{ $r->{targets} }) . " :: ";
		$res .= join(' ', @{ $r->{dependencies} || [] }) . "\n\t";
		$res .= join("\n\t", @{ $r->{actions} }) . "\n\n";
	}
	return $res;
}

sub _Blib_Filter {
	$_ = shift;
	return (/templates/ || /startup\.pl/ || /public_html/);
}

sub _init_dirscan {
	my $self = shift;
	my $bf = $self->blib_filter || $self->can('_Blib_Filter');
	my $fs = ExtUtils::Manifest::maniread();
	my @files = grep { $bf->($_); } keys %$fs;
	return unless @files;
	$self->overrides->{const_config} = sub {
		my $this = shift;
		my $res = $this->MY::SUPER::const_config(@_);
		$this->{PM}->{$_} = "blib/$_" for @files;
		return $res;
	};
}

sub _mm_install {
	return <<ENDS;
install :: all
	./scripts/swit_app.pl install \$(INSTALLSITELIB)
ENDS
}

sub _mm_constants {
	my $str = shift()->MY::SUPER::constants(\@_);
	my $an = Apache::SWIT::Maker::Config->instance->app_name;
	my $rep = "INSTALLSITELIB=\$(SITEPREFIX)/share/$an";
	$str =~ s#INSTALLSITELIB[^\n]+#$rep#;
	return $str;
}

sub _mm_test {
	my $res = shift()->MY::SUPER::test(@_);
	$res =~ s/PERLRUN\)/PERLRUN) -I t\//g;
	return $res;
}

sub _mm_postamble {
	return __PACKAGE__->get_makefile_rules . q{
test :: test_direct test_apache 

APACHE_TEST_FILES = `find t/dual -name "*.t" | sort`

test_direct :: pure_all
	PERL_DL_NONLAZY=1 $(FULLPERLRUN) -I t -I blib/lib t/direct_test.pl $(APACHE_TEST_FILES)

test_apache :: pure_all
	$(RM_F) t/logs/access_log  t/logs/error_log
	ulimit -c unlimited && PERL_DL_NONLAZY=1 $(FULLPERLRUN) -I t -I blib/lib t/apache_test.pl $(APACHE_TEST_FILES)

realclean ::
	$(RM_RF) t/htdocs t/logs
	$(RM_F) t/conf/apache_test_config.pm  t/conf/modperl_inc.pl t/T/Test.pm
	$(RM_F) t/conf/extra.conf t/conf/httpd.conf t/conf/modperl_startup.pl
	$(RM_F) blib/conf/httpd.conf
};
}

my @_swit_overrides = qw(test postamble constants install);

sub _init_swit_sections {
	my $self = shift;
	return if $self->no_swit_overrides;
	$self->overrides({}) unless $self->overrides;
	for my $o (@_swit_overrides) {
		next if $self->overrides->{$o};
		my $f = $self->can("_mm_$o") or next;
		$self->overrides->{$o} = $f;
	}
}

sub write_makefile {
	my $self = shift;
	$self->_init_swit_sections;
	$self->_init_dirscan;
	my $o = $self->overrides || {};
	while (my ($n, $f) = each %$o) {
		no strict 'refs';
		no warnings 'redefine';
		*{ "MY::" . $n } = $f;
	}
	WriteMakefile(@_);
}

sub deploy_httpd_conf {
	my ($class, $from, $to) = @_;
	mkpath("$to/conf");
	my $from_ap = abs_path($from);
	my $to_ap = abs_path($to);
	$_ = read_file("$from_ap/conf/httpd.conf");
	s#$from_ap#$to_ap#g;
	s/\@ServerRoot\@/$to_ap/g;
	conv_forced_write_file("$to_ap/conf/httpd.conf", $_);
}

sub do_install {
	my ($class, $from, $to) = @_;
	ExtUtils::Install::install({ $from, $to });
	$class->deploy_httpd_conf($from, $to);
}

1;
