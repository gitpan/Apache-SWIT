use strict;
use warnings FATAL => 'all';
use lib 'lib';
use Apache::SWIT::Maker::Makefile;

Apache::SWIT::Maker::Makefile->new({ no_swit_overrides => 1, overrides => {
postamble => sub { return q{
config :: t/conf/httpd.conf
	$(NOECHO) $(NOOP)
			
t/conf/httpd.conf :: t/conf/extra.conf.in
	ulimit -c unlimited && PERL_DL_NONLAZY=1 $(FULLPERLRUN) t/apache_test.pl -config

APACHE_TEST_FILES = t/apache/*.t
test :: test_apache
test_apache :: pure_all
	$(RM_F) t/logs/access_log  t/logs/error_log
	ulimit -c unlimited && PERL_DL_NONLAZY=1 $(FULLPERLRUN) -I t/ t/apache_test.pl $(APACHE_TEST_FILES)

realclean ::
	$(RM_RF) t/htdocs t/logs
	$(RM_F) t/conf/apache_test_config.pm  t/conf/modperl_inc.pl
	$(RM_F) t/conf/extra.conf t/conf/httpd.conf t/conf/modperl_startup.pl
	$(RM_RF) blib/conf
}}, } })->write_makefile(
    NAME         => 'Apache::SWIT',
    VERSION_FROM => 'lib/Apache/SWIT.pm', # finds $VERSION
    AUTHOR       => 'Boris Sukholitko (boriss@gmail.com)',
    ABSTRACT     => 'mod_perl server with integrated testing',
    EXE_FILES    => [ 'scripts/swit_init' ],
    PREREQ_PM    => { 'Test::Simple' => 0.44, 'Apache::Test' => '',
	'WWW::Mechanize' => '', 'Template' => '', 'HTML::Tested' => '0.37',
	'ExtUtils::ModuleMaker' => '', 'HTML::Tested::ClassDBI' => '0.17',
	'Apache2::Request' => '', 'Class::Accessor' => '', YAML => '',
	'Apache2::Cookie' => '', 'DBIx::VersionedSchema' => '0.03',
	'Test::TempDatabase' => '0.13', 'Class::DBI::Pg::More' => '0.04',
	'Class::DBI' => '', 'Class::DBI::Pg' => '0.09', 'File::Slurp' => '',
	'IPC::Run' => '', 'HTML::Tested::JavaScript' => '0.12'
	, 'Package::Alias' => '', 'Apache::DB' => ''
    },
);

