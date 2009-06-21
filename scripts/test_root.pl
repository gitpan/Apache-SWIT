#!/usr/bin/perl -w
use strict;
use warnings FATAL => 'all';
use File::Slurp;
use File::Temp qw(tempdir);
use File::Path qw(mkpath);
use File::Basename qw(dirname);

my $what = $ARGV[0];
my @mf = read_file('MANIFEST');
my $td = tempdir('/tmp/swit_root_XXXXXX', CLEANUP => 1);
for my $f (@mf) {
	chomp $f;
	mkpath $td . "/" . dirname($f);
	system("cp -a $f $td/$f") and die $f;
}
chdir $td;
system("chmod -R o-rwx *") and die;
system("perl Makefile.PL") or system("make") or system("make $what");
chdir '/';
