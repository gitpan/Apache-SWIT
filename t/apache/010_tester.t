use strict;
use warnings FATAL => 'all';

use Test::More tests => 38;
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use Data::Dumper;
use File::Slurp;
use Apache::SWIT::Test::Utils;

BEGIN { 
	unlink "/tmp/swit_startup_test";
	use_ok('Apache::SWIT::Test');
	Apache::SWIT::Test->do_startup("AA_ROOT");
}

$ENV{SWIT_HAS_APACHE} = 0;

my $td = tempdir("/tmp/swit_tester_XXXXXXX", CLEANUP => 1);

my @sls = read_file("/tmp/swit_startup_test");
is(@sls, 1) or diag(join("", @sls));
like($sls[0], qr/T::SWIT .*blib.*do_swit_startups/);

Apache::SWIT::Test->make_aliases(the_page => 'T::SWIT', res => 'T::Res');
can_ok('T::SWIT', 'can') or exit 1;
can_ok('T::Res', 'can');

@sls = read_file("/tmp/swit_startup_test");
is(@sls, 1) or diag(join("", @sls));
like($sls[0], qr/T::SWIT .*blib.*do_swit_startups/);
unlike(join("", @sls), qr/T .*Test\.pm/);
unlink("/tmp/swit_startup_test");

my $t = Apache::SWIT::Test->new;
isa_ok($t, 'Apache::SWIT::Test');
is($t->mech, undef);

my @res = $t->the_page_r(base_url => '/test/swit');
is_deeply(\@res, [ { hello => 'world' } ]);

@res = $t->the_page_u(fields => { file => "$td/uuu" });
is(read_file("$td/uuu"), '');
is(unlink("$td/uuu"), 1);
is_deeply(\@res, [ '/test/res/r?res=hhhh' ]);

@res = $t->the_page_u(button => [ but => 'Push' ]
			, fields => { file => "$td/uuu" });
is(read_file("$td/uuu"), 'Push');
is(unlink("$td/uuu"), 1);
is_deeply(\@res, [ '/test/res/r?res=hhhh' ]);

# does nothing
$t->ok_follow_link(text => 'This');
$t->ok_get('/test/www/hello.html');
$t->content_like(qr/HELLO, HTML/);

@res = $t->res_r;
is_deeply(\@res, [ { res => 'hhhh' } ])
	or diag(Dumper(\@res));

$ENV{SWIT_HAS_APACHE} = 1;
$t = Apache::SWIT::Test->new;
isa_ok($t->mech, 'WWW::Mechanize');
@res = $t->the_page_r(base_url => '/test/swit/r');
is_deeply(\@res, [ <<ENDS ]);
<html>
<body>
<form action="u">
hello world
<input type="text" name="file" />
<input type="submit" name="but" value="Push" />
<a href="r">This</a>
</form>
</body>
</html>
ENDS

@res = $t->the_page_u(fields => { file => "$td/uuu" });
is(read_file("$td/uuu"), '');
is(unlink("$td/uuu"), 1);
is_deeply(\@res, [ "hhhh\n" ]);

$t->the_page_r(base_url => '/test/swit/r');
@res = $t->the_page_u(button => [ but => 'Push' ]
		, fields => { file => "$td/uuu" });
is(read_file("$td/uuu"), 'Push');
is(unlink("$td/uuu"), 1);
is_deeply(\@res, [ "hhhh\n" ]);

$t->the_page_r(base_url => '/test/swit/r');
$t->the_page_u(fields => { file => "$td/RESPOND" });
$t->content_like(qr/RESPONSE/);
is(-f "$td/RESPOND", undef);
like(ASTU_Read_Access_Log(), qr/RESPOND.*200/);

Apache::SWIT::Test->make_aliases("another/page" => 'T::SWIT');
$t->root_location('/test');
@res = $t->another_page_r(make_url => 1);
is_deeply(\@res, [ <<ENDS ]);
<html>
<body>
<form action="u">
hello world
<input type="text" name="file" />
<input type="submit" name="but" value="Push" />
<a href="r">This</a>
</form>
</body>
</html>
ENDS

# works
$t->ok_follow_link(text => 'This');
$t->ok_get('/test/www/hello.html');
$t->content_like(qr/HELLO, HTML/);
$t->ok_get('/test/www/nothing.html', 404);

# relative to root location
$t->ok_get('www/hello.html', 200);
