use strict;
use warnings FATAL => 'all';

use Test::More tests => 12;
use Test::TempDatabase;
use File::Slurp;
Test::TempDatabase->become_postgres_user;

BEGIN { use_ok('Apache::SWIT::Test::ModuleTester'); }

my $mt = Apache::SWIT::Test::ModuleTester->new({ root_class => 'TTT' });
chdir $mt->root_dir;
$mt->make_swit_project;
ok(-f 'LICENSE');
ok(-f 'lib/TTT/DB/Schema.pm');

$mt->replace_in_file('lib/TTT/UI/Index.pm', ']'
		, ', { is_sealed => 1 } ]');

is($ENV{APACHE_SWIT_HT_SEAL}, undef);
my $make = "perl Makefile.PL && make";
my $res = `$make test_direct 2>&1`;
like($res, qr/Failed/); # or readline(\*STDIN);
like($res, qr/HT_SEALED/);

$mt->replace_in_file('t/dual/001_load.t', 'first', 'HT_SEALED_first');
$res = `make test_direct 2>&1`;
unlike($res, qr/Failed/); # or readline(\*STDIN);
like($res, qr/success/);

write_file('t/dual/030_load.t', <<'ENDS');
use strict;
use warnings FATAL => 'all';

use Test::More tests => 2;

BEGIN {
        use_ok('T::Test');
};

my $t = T::Test->new;

package M;
use base 'WWW::Mechanize';

sub get {
	Test::More::diag("MGET");
	shift()->SUPER::get(@_);
}

package main;

$t->mech(M->new) if $t->mech;
$t->ok_get('www/main.css');
ENDS

append_file('t/dual/001_load.t', <<'ENDS');
if ($t->mech) {
	$t->mech_get_base('/ttt/www/main.css');
	diag($t->mech->content);
}
ENDS

$res = `make test_apache 2>&1`;
unlike($res, qr/Failed/); # or readline(\*STDIN);
like($res, qr/success/);
like($res, qr/CSS/);
like($res, qr/MGET/);

chdir '/';
