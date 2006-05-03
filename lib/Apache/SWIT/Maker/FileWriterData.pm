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
__PACKAGE__->make_tested_form(form => default_value => u => children => [
		first => 'marked_value' ]);

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

__PACKAGE__->add_file({ name => 'tt_file', manifest => 1
	, tmpl_options => { START_TAG => '<%', END_TAG => '%>' } }, <<'EM');
<html>
<body>
[% form %]
<% content %>
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

__PACKAGE__->set_up_table('[% table %]', ColumnGroup => 'Essential');

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
__PACKAGE__->make_tested_hidden('ht_id', cdbi_bind => 'Primary');
__PACKAGE__->make_tested_submit('submit_button', default_value => 'Submit');
__PACKAGE__->make_tested_submit('delete_button', default_value => 'Delete');
__PACKAGE__->make_tested_form(form => default_value => u => children => [
	[% FOREACH fields %][% field %] => edit_box => { cdbi_bind => '' },
[% END %]]);
__PACKAGE__->bind_to_class_dbi('[% db_class %]');
__PACKAGE__->load_db_constraints;

package [% full_class %];
use base qw(Apache::SWIT::HTPage);

sub ht_root_class { 
	return '[% full_class %]::Root';
}

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	$root->cdbi_load;
	return $root;
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
	$root->delete_button
		? $root->cdbi_delete
		: $root->cdbi_create_or_update;
	return "r";
}

1;
EM

__PACKAGE__->add_file({ name => 'info_ht_page_pm' , manifest => 1 }, <<'EM');
use strict;
use warnings FATAL => 'all';

package [% full_class %]::Root;
use base 'HTML::Tested::ClassDBI';
use [% db_class %];
__PACKAGE__->make_tested_form(form => default_value => u => children => [
	[% FOREACH fields %][% field %] => marked_value => { cdbi_bind => '' },
[% END %]]);
__PACKAGE__->make_tested_link('edit_link'
		, href_format => '../form/r?ht_id=%s'
		, caption => 'Edit', cdbi_bind => [ 'Primary' ]);
__PACKAGE__->bind_to_class_dbi('[% db_class %]');

package [% full_class %];
use base qw(Apache::SWIT::HTPage);

sub ht_root_class { 
	return '[% full_class %]::Root';
}

sub ht_swit_render {
	my ($class, $r, $root) = @_;
	$root->cdbi_load;
	return $root;
}

sub ht_swit_update {
	my ($class, $r, $root) = @_;
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
__PACKAGE__->make_tested_link('[% link_field %]'
		, href_format => '../info/r?ht_id=%s'
		, cdbi_bind => [ [% link_field %] => 'Primary' ]);
[% FOREACH fields %]__PACKAGE__->make_tested_marked_value('[% field %]', cdbi_bind => '');
[% END %]
__PACKAGE__->bind_to_class_dbi('[% db_class %]');

package [% full_class %]::Root;
use base 'HTML::Tested';
__PACKAGE__->make_tested_form('form', default_value => 'u');
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

__PACKAGE__->add_file({ name => 'conf/makefile_rules.yaml', manifest => 1 }
		, <<'EM');
- targets: [ config ]
  dependencies: 
    - t/conf/httpd.conf
    - conf/httpd.conf
  actions:
    - $(NOECHO) $(NOOP)
- targets: [ t/conf/httpd.conf ]
  dependencies: 
    - t/conf/extra.conf.in
  actions:
    - PERL_DL_NONLAZY=1 $(FULLPERLRUN) t/apache_test_run.pl -config
- targets: [ conf/httpd.conf ]
  dependencies:
    - conf/swit.yaml
    - conf/httpd.conf.in
  actions:
    - ./scripts/swit_app.pl regenerate_httpd_conf
EM

1;
