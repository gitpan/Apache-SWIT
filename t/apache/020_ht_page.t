use strict;
use warnings FATAL => 'all';

use Test::More tests => 27;
use File::Temp qw(tempdir);
use File::Slurp;
use Apache::SWIT::Session;
use Apache::SWIT::Test::Utils;

BEGIN { use_ok('T::Test');
	;
	use_ok('Apache::SWIT::HTPage'); 
	use_ok('T::HTPage');
}

$ENV{SWIT_HAS_APACHE} = 0;

my $td = tempdir("/tmp/swit_ht_page_XXXXXXX", CLEANUP => 1);

T::Test->make_aliases(another_page => 'T::HTPage',
		"and/another" => 'T::HTPage');

my $t = T::Test->new({ session_class => 'Apache::SWIT::Session' });
$t->ok_ht_another_page_r(base_url => '/test/ht_page', ht => { 
		hello => 'world', HT_SEALED_hid => 'secret', v1 => undef, });
my $res = $t->ok_ht_another_page_r(base_url => '/test/ht_page', 
	param => { v1 => 'hi', },
	ht => { hello => 'world', v1 => 'hi', });
is($res, 1);

$t->ok_ht_another_page_r(base_url => '/test/ht_page', 
	param => { HT_SEALED_hid => 'momo', },
	ht => { HT_SEALED_hid => 'momo' });

write_file("$td/up.txt", "Hello\nworld\n");

my @x = $t->ht_another_page_u(ht => { file => "$td/uuu"
					, up => "$td/up.txt" });
my $ur = read_file("$td/uuu");
is(unlink("$td/uuu"), 1);
is_deeply(\@x, [ '/test/basic_handler' ]);
is($ur, "$td/up.txt\nHello\nworld\n");

$ENV{SWIT_HAS_APACHE} = 1;
$t = T::Test->new({ session_class => 'Apache::SWIT::Session' });
$t->ok_ht_another_page_r(base_url => '/test/ht_page/r', ht => { 
		hello => 'world', HT_SEALED_hid => 'secret' });
like($t->mech->content, qr/got more/);

$t->ok_ht_another_page_r(base_url => '/test/ht_page/r'
	, param => { HT_SEALED_hid => 'gaga' }, ht => { 
		hello => 'world', HT_SEALED_hid => 'gaga' });

$t->ok_ht_another_page_r(param => { HT_SEALED_hid => 'gaga' }, ht => { 
		hello => 'world', HT_SEALED_hid => 'gaga' });

@x = $t->ht_another_page_r(base_url => '/test/ht_page/r'
		, ht => { hello => 'life' });
isnt($x[0], undef);

is(read_file("$td/up.txt"), "Hello\nworld\n");
is(unlink("$td/uuu"), 0);

@x = $t->ht_another_page_u(ht => { file => "$td/uuu", up => "$td/up.txt" });
$ur = read_file("$td/uuu");
is(unlink("$td/uuu"), 1);
is(@x, 1);
like($x[0], qr/hhhh/);
is($ur, "$td/up.txt\nHello\nworld\n");

my @al1 = ASTU_Read_Access_Log();
$t->mech->reload;
my @al2 = ASTU_Read_Access_Log();
is(@al2, @al1 + 1);

like($t->mech->content, qr/hhhh/);
is(unlink("$td/uuu"), 0);

$t->ok_ht_and_another_r(base_url => '/test/ht_page/r', ht => { 
		hello => 'world' });

eval {
	$t->ht_another_page_u(form_name => 'aa'
			, ht => { inv_up => "$td/up.txt" });
};
like($@, qr/multipart/);

eval {
	local *STDERR;
	open STDERR, '>/dev/null';
	$t->ht_another_page_u(form_name => 'bwbbw'
			, ht => { inv_up => "$td/up.txt" });
};
like($@, qr/No form_name/);
