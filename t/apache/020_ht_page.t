use strict;
use warnings FATAL => 'all';

use Test::More tests => 11;
use File::Temp qw(tempdir);

BEGIN { use_ok('Apache::SWIT::HTPage'); 
	use_ok('T::HTPage');
	use_ok('Apache::SWIT::Test');
}

my $td = tempdir("/tmp/swit_ht_page_XXXXXXX", CLEANUP => 1);

Apache::SWIT::Test->make_aliases(another_page => 'T::HTPage');

my $t = Apache::SWIT::Test->new;
$t->ok_ht_another_page_r(base_url => '/test/ht_page', ht => { 
		hello => 'world', v1 => undef, });
$t->ok_ht_another_page_r(base_url => '/test/ht_page', 
	param => { v1 => 'hi', },
	ht => { hello => 'world', v1 => 'hi', });

my @x = $t->ht_another_page_u(ht => { file => "$td/uuu" });
is(unlink("$td/uuu"), 1);
is_deeply(\@x, [ '/test/basic_handler' ]);

$ENV{SWIT_HAS_APACHE} = 1;
$t = Apache::SWIT::Test->new;
$t->ok_ht_another_page_r(base_url => '/test/ht_page/r', ht => { 
		hello => 'world' });
@x = $t->ht_another_page_r(base_url => '/test/ht_page/r', ht => { hello => 'life' });
isnt($x[0], undef);

@x = $t->ht_another_page_u(ht => { file => "$td/uuu" });
is(unlink("$td/uuu"), 1);
is_deeply(\@x, [ 'hhhh' ]);

