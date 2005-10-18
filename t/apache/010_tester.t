use strict;
use warnings FATAL => 'all';

use Test::More tests => 13;
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use Data::Dumper;

BEGIN { 
	use_ok('Apache::SWIT::Test');
	use_ok('T::SWIT');
	use_ok('T::Res');
}

my $td = tempdir("/tmp/swit_tester_XXXXXXX", CLEANUP => 1);

Apache::SWIT::Test->make_aliases(the_page => 'T::SWIT', res => 'T::Res');

my $t = Apache::SWIT::Test->new;
isa_ok($t, 'Apache::SWIT::Test');
is($t->mech, undef);

my @res = $t->the_page_r(base_url => '/test/swit');
is_deeply(\@res, [ 'templates/test.tt', { hello => 'world' } ]);

@res = $t->the_page_u(fields => { file => "$td/uuu" });
is(unlink("$td/uuu"), 1);
is_deeply(\@res, [ '/test/res/r?res=hhhh' ]);

@res = $t->res_r;
is_deeply(\@res, [ 'templates/res.tt', { res => 'hhhh' } ])
	or diag(Dumper(\@res));

$ENV{SWIT_HAS_APACHE} = 1;
$t = Apache::SWIT::Test->new;
isa_ok($t->mech, 'Apache::SWIT::Test::Mechanize');
@res = $t->the_page_r(base_url => '/test/swit/r');
is_deeply(\@res, [ <<ENDS ]);
<html>
<body>
<form action="u">
hello world
<input type="text" name="file" />
</form>
</body>
</html>
ENDS

@res = $t->the_page_u(fields => { file => "$td/uuu" });
is(unlink("$td/uuu"), 1);
is_deeply(\@res, [ "hhhh\n" ]);
