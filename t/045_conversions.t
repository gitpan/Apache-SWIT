use strict;
use warnings FATAL => 'all';

use Test::More tests => 19;
use File::Slurp;
use File::Temp qw(tempdir);
use Test::TempDatabase;

BEGIN { use_ok('Apache::SWIT::Maker::Conversions');
	use_ok('Apache::SWIT::Maker::Manifest');
}

use Carp;
BEGIN { $SIG{__WARN__} = sub { diag(Carp::longmess); } };

Test::TempDatabase->become_postgres_user;

is(conv_table_to_class('order'), 'Order');
is(conv_table_to_class('customer_order'), 'CustomerOrder');

is(conv_make_full_class('AA', 'B', 'C'), 'AA::B::C');
is(conv_make_full_class('AA', 'B', 'AA::DD'), 'AA::DD');

is(conv_next_dual_test("a/b.pm\nt/323_one.t\nt/dual/110_two.t\n"
			. "t/dual/222_e.t"), "232");
is(conv_next_dual_test("a/b.pm\nt/323_one.t\nt/dual/110_two.t\n"
			. "t/dual/222_e.t\n"), "232");
is(conv_next_dual_test("t/dual/001_load.t"), "011");

is(conv_class_to_app_name("Hello::World"), "hello_world");

my $td = tempdir('/tmp/pltemp_045_XXXXXX', CLEANUP => 1);
write_file("$td/aaa.txt", "ffff\n");
chmod 0444, "$td/aaa.txt";
conv_forced_write_file("$td/aaa.txt", "gggg\n");
is(read_file("$td/aaa.txt"), "gggg\n");
ok(! -w "$td/aaa.txt");

chdir $td;
swmani_write_file("boo/ggg.txt", "hoho");
like(read_file('MANIFEST'), qr/ggg/);
ok(-f "boo/ggg.txt");
swmani_write_file("boo/ccc.txt", "hoho");

eval { swmani_write_file("boo/ccc.txt", "hoho"); };
like($@, qr/Cowardly/);

my $mf = read_file('MANIFEST');
like($mf, qr/ggg/);
like($mf, qr/ccc/);
ok(-f "boo/ccc.txt");
chdir '/';

is(conv_next_dual_test(<<ENDS), '021');
t/001_load.t
t/dual/001_load.t
t/dual/011_the_table.t
ENDS
