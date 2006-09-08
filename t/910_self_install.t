use strict;
use warnings FATAL => 'all';

use Test::More tests => 2;
use File::Temp qw(tempdir);
use File::Basename qw(dirname);

my $td = tempdir("/tmp/pltemp_910_XXXXXX", CLEANUP => 1);
chdir(dirname($0) . "/../");
my $res = `perl Makefile.PL && make install SITEPREFIX=$td/inst 2>&1`;
is($?, 0) or diag($res);
isnt(-d "$td/inst/share/perl", undef) or diag($res);

