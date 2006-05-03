use strict;
use warnings FATAL => 'all';

use Test::More tests => 8;

BEGIN { use_ok('Apache::SWIT::Maker::Conversions'); }

is(conv_table_to_class('order'), 'Order');
is(conv_table_to_class('customer_order'), 'CustomerOrder');

is(conv_make_full_class('AA', 'B', 'C'), 'AA::B::C');
is(conv_make_full_class('AA', 'B', 'AA::DD'), 'AA::DD');

is(conv_next_dual_test("a/b.pm\nt/323_one.t\nt/dual/110_two.t\n"
			. "t/dual/222_e.t\n"), "232");
is(conv_next_dual_test("t/dual/001_load.t"), "011");

is(conv_class_to_app_name("Hello::World"), "hello_world");
