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
	my $tested = $class->ht_root_class->ht_convert_request_to_tree($r);
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
	if ($err) {
		eval { $dbh->rollback };
		my $exc = "Original exception: $err";
		$exc .= "\nRollback exception: $@" if $@;
		$class->swit_die($exc, $r, $tested);
	}
	$dbh->commit;
	return $res;
}

sub swit_update {
	my ($class, $r) = @_;
	my $tested = $class->ht_root_class->ht_convert_request_to_tree($r);
	my @errs = $tested->ht_validate;
	$class->swit_die("ht_validate failed", $r, $tested, \@errs) if @errs;
	return $class->ht_swit_transactional_update($r, $tested);
}

1;
