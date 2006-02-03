package MY;

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Apache::SWIT',
    VERSION_FROM => 'lib/Apache/SWIT.pm', # finds $VERSION
    AUTHOR       => 'Boris Sukholitko (boriss@gmail.com)',
    ABSTRACT     => '',
    PREREQ_PM    => { 'Test::Simple' => 0.44, 'Apache::Test' => '',
	'WWW::Mechanize' => '', 'Template' => '', 'HTML::Tested' => '',
	'ExtUtils::ModuleMaker' => '',
	'Apache::Request' => '', 'Class::Accessor' => '', YAML => '',
	'Apache::Cookie' => '', 'DBIx::VersionedSchema' => '',
	'Test::TempDatabase' => '', 'Class::Singleton' => '',
	'Class::DBI' => '', 'File::Slurp' => '',
    },
);

sub postamble { return q{
config :: t/conf/httpd.conf
	$(NOECHO) $(NOOP)
			
t/conf/httpd.conf :: t/conf/extra.conf.swit
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
	$(RM_F) t/conf/extra.conf.in
}}

