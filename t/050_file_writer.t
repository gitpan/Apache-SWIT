use strict;
use warnings FATAL => 'all';

use Test::More tests => 7;
use File::Temp qw(tempdir);
use File::Slurp;

BEGIN { use_ok('Apache::SWIT::Maker::FileWriter'); }

package H;
use base 'Apache::SWIT::Maker::FileWriter';
__PACKAGE__->add_file({ name => 'first' }, <<EF);
Hello [% p %]
EF

package main;

my $td = tempdir('/tmp/apache_swit_050_XXXXXX', CLEANUP => 1);
my $fw = H->new({ root_dir => $td });
$fw->write_first({ p => 'world' });
is(read_file("$td/first"), "Hello world\n");

H->add_file({ name => 'M/A.pm' }, 'Hello [% v %]');
$fw->write_m_a_pm({ v => 'pm' });
is(read_file("$td/M/A.pm"), "Hello pm");

$fw->write_m_a_pm({ v => 'pm' }, { path => 'M/B.pm' });
is(read_file("$td/M/B.pm"), "Hello pm");

write_file("$td/MANIFEST", "1");
H->add_file({ name => 'M/C.pm', manifest => 1 }, 'Mani [% v %]');
$fw->write_m_c_pm({ v => 'pm' });
is(read_file("$td/M/C.pm"), "Mani pm");
is(read_file("$td/MANIFEST"), "1\nM/C.pm");

my $cur = H->new;
is($cur->root_dir, '.');
undef $cur;

