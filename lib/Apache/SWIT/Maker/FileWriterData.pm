use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Maker::FileWriterData;
use base 'Apache::SWIT::Maker::FileWriter';

__PACKAGE__->add_file({ name => 'scripts/swit_app.pl'
		, manifest => 1 }, <<'EM');
#!/usr/bin/perl -w
use strict;
use [% class %];
my $f = shift(@ARGV);
[% class %]->new->$f(@ARGV);
EM

__PACKAGE__->add_file({ name => 'ht_page_pm' , manifest => 1 }, <<'EM');
use strict;
use warnings FATAL => 'all';

package [% full_class %]::Root;
use base 'HTML::Tested';
__PACKAGE__->make_tested_marked_value('first');

package [% full_class %];
use base qw(Apache::SWIT::HTPage);

sub ht_root_class { 
	return [% ht_root %];
}

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	return $root;
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	return "r";
}

1;
EM

__PACKAGE__->add_file({ name => 'tt_file', manifest => 1 }, <<'EM');
<html>
<body>
<form action="u" method="post">
[% content %]
</form>
</body>
</html>
EM

__PACKAGE__->add_file({ name => 't/direct_test.pl', manifest => 1 }, <<'EM');
use strict;
use warnings FATAL => 'all';
use Test::Harness;
use T::TempDB;

runtests(@ARGV);
EM

__PACKAGE__->add_file({ name => 'db_pm', manifest => 1 }, <<'EM');
use strict;
use warnings FATAL => 'all';

package [% class %];
use base '[% root %]::DB::Base';

__PACKAGE__->set_up_table('[% table %]');

1;
EM

__PACKAGE__->add_file({ name => 'test', manifest => 1 }, <<'EM');
use strict;
use warnings FATAL => 'all';

use Test::More tests => [% plan %];

BEGIN { [% FOREACH use_oks %]
	use_ok('[% module %]');[% END %]
};

[% content %]
EM

sub write_dual_test {
	my ($self, $f, $plan, $content, @uses) = @_;
	$self->write_test({
			plan => $plan + 1 + scalar(@uses),
			use_oks => [ { module => 'T::Test' }
				, map { { module => $_ } } @uses ],
			content => "my \$t = T::Test->new;\n$content",
		} , { path => "t/dual/$f.t" });
}

__PACKAGE__->add_file({ name => 'form_ht_page_pm' , manifest => 1 }, <<'EM');
use strict;
use warnings FATAL => 'all';

package [% full_class %]::Root;
use base 'HTML::Tested::ClassDBI';
use [% db_class %];
[% FOREACH fields %]__PACKAGE__->make_tested_edit_box('[% field %]');
[% END %]
__PACKAGE__->bind_to_class_dbi('[% db_class %]'
[% FOREACH fields %]	, [% field %] => '[% field %]'
[% END %]);

package [% full_class %];
use base qw(Apache::SWIT::HTPage);

sub ht_root_class { 
	return '[% full_class %]::Root';
}

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	return $root;
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	$root->cdbi_create_or_update;
	return "r";
}

1;
EM

__PACKAGE__->add_file({ name => 'list_ht_page_pm' , manifest => 1 }, <<'EM');
use strict;
use warnings FATAL => 'all';

package [% full_class %]::Root::Item;
use base 'HTML::Tested::ClassDBI';
use [% db_class %];
[% FOREACH fields %]__PACKAGE__->make_tested_marked_value('[% field %]');
[% END %]
__PACKAGE__->bind_to_class_dbi('[% db_class %]'
[% FOREACH fields %]	, [% field %] => '[% field %]'
[% END %]);

package [% full_class %]::Root;
use base 'HTML::Tested';
__PACKAGE__->make_tested_list('[% list_name %]', __PACKAGE__ . '::Item');

package [% full_class %];
use base qw(Apache::SWIT::HTPage);

sub ht_root_class { 
	return '[% full_class %]::Root';
}

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	$root->[% list_name %]_containee_do(query_class_dbi => 'retrieve_all');
	return $root;
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	return "r";
}

1;
EM

__PACKAGE__->add_file({ name => 'db_base_pm', manifest => 1 }, <<'EM');
use base 'Class::DBI::Pg';
use [% connection %];

$Class::DBI::Weaken_Is_Available = 0;
sub db_Main {
	return [% connection %]->instance->db_handle;
}
EM

1;
