use strict;
use warnings FATAL => 'all';

use Test::More tests => 13;
use File::Temp qw(tempdir);

BEGIN { use_ok('Apache::SWIT::HTPage'); 
	use_ok('T::HTPage');
	use_ok('Apache::SWIT::Test');
}

$ENV{SWIT_HAS_APACHE} = 0;

my $td = tempdir("/tmp/swit_ht_page_XXXXXXX", CLEANUP => 1);

Apache::SWIT::Test->make_aliases(another_page => 'T::HTPage',
		"and/another" => 'T::HTPage');

my $t = Apache::SWIT::Test->new;
$t->ok_ht_another_page_r(base_url => '/test/ht_page', ht => { 
		hello => 'world', HT_SEALED_hid => 'secret', v1 => undef, });
$t->ok_ht_another_page_r(base_url => '/test/ht_page', 
	param => { v1 => 'hi', },
	ht => { hello => 'world', v1 => 'hi', });

$t->ok_ht_another_page_r(base_url => '/test/ht_page', 
	param => { HT_SEALED_hid => 'momo', },
	ht => { HT_SEALED_hid => 'momo' });

my @x = $t->ht_another_page_u(ht => { file => "$td/uuu" });
is(unlink("$td/uuu"), 1);
is_deeply(\@x, [ '/test/basic_handler' ]);

$ENV{SWIT_HAS_APACHE} = 1;
$t = Apache::SWIT::Test->new;
$t->ok_ht_another_page_r(base_url => '/test/ht_page/r', ht => { 
		hello => 'world', HT_SEALED_hid => 'secret' });
@x = $t->ht_another_page_r(base_url => '/test/ht_page/r'
		, ht => { hello => 'life' });
isnt($x[0], undef);

@x = $t->ht_another_page_u(ht => { file => "$td/uuu" });
is(unlink("$td/uuu"), 1);
is_deeply(\@x, [ 'hhhh' ]);

$t->ok_ht_and_another_r(base_url => '/test/ht_page/r', ht => { 
		hello => 'world' });

