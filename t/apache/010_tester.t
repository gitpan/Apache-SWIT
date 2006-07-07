use strict;
use warnings FATAL => 'all';

use Test::More tests => 24;
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use Data::Dumper;
use File::Slurp;

BEGIN { 
	use_ok('Apache::SWIT::Test');
	use_ok('T::SWIT');
	use_ok('T::Res');
}

$ENV{SWIT_HAS_APACHE} = 0;

my $td = tempdir("/tmp/swit_tester_XXXXXXX", CLEANUP => 1);

Apache::SWIT::Test->make_aliases(the_page => 'T::SWIT', res => 'T::Res');

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

@res = $t->res_r;
is_deeply(\@res, [ { res => 'hhhh' } ])
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
