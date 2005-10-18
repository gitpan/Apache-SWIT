use strict;
use warnings FATAL => 'all';

use Test::More tests => 5;
use File::Temp qw(tempdir);

BEGIN { use_ok('Apache::SWIT::Maker'); }

delete $ENV{TEST_FILES};
delete $ENV{MAKEFLAGS};
delete $ENV{MAKEOVERRIDES};

my $td = tempdir('/tmp/swit_install_XXXXXX', CLEANUP => 1);
chdir $td;
`modulemaker -I -n TTT`;
ok(-f './TTT/LICENSE');
chdir 'TTT';

Apache::SWIT::Maker->new->write_initial_files();

`perl Makefile.PL`;
my @lines = `make install SITEPREFIX=$td/inst 2>&1`;
isnt(-d "$td/inst/share/ttt", undef) or do {
	diag(join('', @lines));
#	diag("$td");
#	readline(\*STDIN);
};

isnt(-f "$td/inst/share/ttt/conf/startup.pl", undef);
like(Apache::SWIT::Maker::rf("$td/inst/share/ttt/conf/httpd.conf"), 
		qr#TTT_ROOT $td/inst/share/ttt\n#);

chdir '/';
