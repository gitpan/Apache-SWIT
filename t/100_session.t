use strict;
use warnings FATAL => 'all';

use Test::More tests => 19;

BEGIN { use_ok('Apache::SWIT::Session'); }
use File::Temp qw(tempdir);
use File::Path qw(rmtree);
use Data::Dumper;

my $td = tempdir("/tmp/apache_swit_session_XXXXXX");

package MySession;
use base 'Apache::SWIT::Session';

__PACKAGE__->add_var('hello');
__PACKAGE__->add_var('bye', depends_on => [ 'hello' ]);
__PACKAGE__->add_var('bye_bye', depends_on => [ 'bye' ]);
__PACKAGE__->add_var('infdef', depends_on => [ 'bye' ], 
		inflate => sub { shift() . '_foooooo'; },
		deflate => sub { $_[0] =~ s/_foooooo//; return $_[0]; });

sub sessions_dir { return $td; }

package main;

my $s = MySession->new(_stash => { hello => 'world' });
is($s->get_hello, 'world');

is($s->delete_hello, 'world');
is_deeply($s->{_stash}, {});

$s->set_hello('life');
is_deeply($s->{_stash}, { hello => 'life' });

$s->set_bye('world');
is_deeply($s->{_stash}, { hello => 'life', bye => 'world' });
$s->set_hello('planet');
is_deeply($s->{_stash}, { hello => 'planet' });

$s->set_bye('world');
$s->set_bye_bye('earth');
is_deeply($s->{_stash}, { hello => 'planet', bye => 'world', bye_bye => 'earth', });
is($s->delete_hello, 'planet');
is_deeply($s->{_stash}, {});

$s->set_hello('planet');
$s->set_bye('world');
$s->set_infdef('defme_foooooo');
is_deeply($s->{_stash}, { hello => 'planet', bye => 'world', 
		infdef => 'defme', });
is($s->get_infdef, 'defme_foooooo');

isnt($s->session_id, undef);

my $s2 = MySession->new(session_id => $s->session_id);
is($s2->session_id, $s->session_id);

$s->write_stash;
$s->{_stash} = {};
is($s->get_infdef, undef);
$s->read_stash;
is($s->get_infdef, 'defme_foooooo');

my @msg = map { rand(1023) } 1 .. 5000;
$s->set_bye_bye([ @msg ]);
is_deeply($s->get_bye_bye, \@msg);
$s->write_stash;
my %stash = %{ $s->{_stash} };
$s->read_stash;
is_deeply($s->{_stash}, \%stash) or diag(Dumper($s->{_stash}));

my @children;
for my $i (1 .. 5) {
	my $pid = fork;
	if ($pid) {
		push @children, $pid;
		next;
	} else {
		for (1 .. 10) {
			$s->read_stash;
			$s->write_stash;
			$s->read_stash;
		}
		exit;
	}
}
waitpid($_, 0) for @children;
$s->read_stash;
is_deeply($s->{_stash}, \%stash) or diag(Dumper($s->{_stash}));

rmtree($td);

