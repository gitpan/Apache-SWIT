use strict;
use warnings FATAL => 'all';

use Test::More tests => 11;
use File::Temp qw(tempdir);

BEGIN { use_ok('Apache::SWIT::Maker');
	use_ok('Apache::SWIT::Test::ModuleTester');
}

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
my $td = $mt->root_dir;
chdir $td;

Apache::SWIT::Maker::wf_path('conf/makefile_rules.yaml', <<ENDS);
- target: config
  dependencies: 
    - t/conf/httpd.conf
    - conf/httpd.conf
  actions:
    - \$(NOECHO) \$(NOOP)
- target: t/conf/httpd.conf
  dependencies: 
    - t/conf/extra.conf.in
  actions:
    - PERL_DL_NONLAZY=1 \$(FULLPERLRUN) t/apache_test_run.pl -config
ENDS
is(Apache::SWIT::Maker->get_makefile_rules, <<ENDS);
config :: t/conf/httpd.conf conf/httpd.conf
	\$(NOECHO) \$(NOOP)

t/conf/httpd.conf :: t/conf/extra.conf.in
	PERL_DL_NONLAZY=1 \$(FULLPERLRUN) t/apache_test_run.pl -config

ENDS

`modulemaker -I -n TTT`;
ok(-f './TTT/LICENSE');
chdir 'TTT';

Apache::SWIT::Maker->new->write_initial_files();

`./scripts/swit_app.pl add_class TTT::SomeClass`;
ok(-f 'lib/TTT/SomeClass.pm');

`./scripts/swit_app.pl add_class AnotherClass`;
ok(-f 'lib/TTT/AnotherClass.pm');

`./scripts/swit_app.pl add_ht_page TTT::SomePage`;
ok(-f 'lib/TTT/SomePage.pm');

`./scripts/swit_app.pl add_ht_page AnotherPage`;
ok(-f 'lib/TTT/UI/AnotherPage.pm');

`perl Makefile.PL`;
my @lines = `make install SITEPREFIX=$td/inst 2>&1`;
isnt(-d "$td/inst/share/ttt", undef) or do {
	diag(join('', @lines));
	diag("$td");
	readline(\*STDIN);
};
is(-d "$td/inst/share/perl", undef);

like(Apache::SWIT::Maker::rf("$td/inst/share/ttt/conf/httpd.conf"), 
		qr#TTT_ROOT $td/inst/share/ttt\n#);

chdir '/';
