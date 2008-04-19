use strict;
use warnings FATAL => 'all';

package Apache::SWIT::HTPage;
use base 'Apache::SWIT';
use HTML::Tested;
use Apache::SWIT::DB::Connection;

sub ht_root_class { return shift() . '::Root'; }

sub ht_make_root_class {
	my $rc = shift()->ht_root_class;
	no strict 'refs';
	@{ "$rc\::ISA" } = (shift() || 'HTML::Tested');
	return $rc;
}

sub swit_render {
	my ($class, $r) = @_;
	my $stash = {};
	my %pars = map { ($_, $r->param($_)) } $r->param;
	my $tested = $class->ht_root_class->ht_load_from_params(%pars);
	my $root;
	eval { $root = $class->ht_swit_render($r, $tested); };
	$class->swit_die("render failed: $@", $r, $tested) if $@;
	my $opq = $r->pnotes('PrevRequestOpaque');
	$tested->ht_merge_params(%$opq) if $opq;
	$root->ht_render($stash);
	return $stash;
}

sub ht_swit_update_die {
	my ($class, $err, $r, $tested, $args) = @_;
	$class->swit_die("Update exception: $err", $r, $tested);
}

sub ht_swit_transactional_update {
	my ($class, $r, $tested, $args) = @_;
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
	$err .= "\nRollback exception: $@" if $@;
EXCEPTION:
	$res = $class->ht_swit_update_die($err, $r, $tested, $args);
	return [ 'SUBREQUEST', $res, $args ];
}

sub ht_swit_validate_die {
	my ($class, $r, $root, $args, $errs) = @_;
	$class->swit_die("ht_validate failed", $r, $root, $errs);
}

sub ht_swit_validate {
	my ($class, $r, $root, $args) = @_;
	my @errs = $root->ht_validate or return;
	return $class->ht_swit_validate_die($r, $root, $args, \@errs);
}

sub swit_update {
	my ($class, $r) = @_;
	my %args = map { ($_, $r->param($_)) } $r->param;
	if ($r->body_status !~ 'End of file') {
		$args{ $r->upload($_)->name } = $r->upload($_) for $r->upload;
	}
		
	my $tested = $class->ht_root_class->ht_load_from_params(%args);
	my $res = $class->ht_swit_validate($r, $tested, \%args);
	return [ 'SUBREQUEST', $res, \%args ] if ($res);
	return $class->ht_swit_transactional_update($r, $tested, \%args);
}

1;
