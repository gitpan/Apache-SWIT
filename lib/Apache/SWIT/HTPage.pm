use strict;
use warnings FATAL => 'all';

package Apache::SWIT::HTPage;
use base 'Apache::SWIT';
use HTML::Tested;
use Apache::SWIT::DB::Connection;

sub ht_root_class { return shift() . '::Root'; }

sub swit_render {
	my ($class, $r) = @_;
	my $stash = {};
	my %pars = map { ($_, $r->param($_)) } $r->param;
	my $tested = $class->ht_root_class->ht_load_from_params(%pars);
	my $root;
	eval { $root = $class->ht_swit_render($r, $tested); };
	$class->swit_die("render failed: $@", $r, $tested) if $@;
	$root->ht_render($stash);
	return $stash;
}

sub ht_swit_transactional_update {
	my ($class, $r, $tested) = @_;
	my $dbh = Apache::SWIT::DB::Connection->instance->db_handle;
	my $res;
	$dbh->begin_work;
	eval { $res = $class->ht_swit_update($r, $tested); };
	my $err = $@;
	goto ROLLBACK if $err;
	eval { $dbh->commit; };
	$err = $@;
	goto EXCEPTION if $err;
	return $res;

ROLLBACK:
	eval { $dbh->rollback };
	my $re = "\nRollback exception: $@" if $@;
EXCEPTION:
	$class->swit_die("Original exception: $err" . ($re || ""), $r, $tested);
}

sub swit_update {
	my ($class, $r) = @_;
	my @pars = map { ($_, $r->param($_)) } $r->param;
	push @pars, map { ($r->upload($_)->name, $r->upload($_)) } $r->upload
		if $r->body_status !~ 'End of file';
	my $tested = $class->ht_root_class->ht_load_from_params(@pars);
	my @errs = $tested->ht_validate;
	$class->swit_die("ht_validate failed", $r, $tested, \@errs) if @errs;
	return $class->ht_swit_transactional_update($r, $tested);
}

1;
