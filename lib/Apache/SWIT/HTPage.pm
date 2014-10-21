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
	@{ "$rc\::ISA" } = (shift() || 'HTML::Tested') unless @{ "$rc\::ISA" };
	return $rc;
}

sub swit_render {
	my ($class, $r) = @_;
	my $stash = {};
	my %pars = %{ $r->param || {} };

	my $supr = $r->prev->pnotes('PrevRequestSuppress') if $r->prev;
	if ($supr) {
		delete $pars{$_} for @$supr;
	}

	my $tested = $class->ht_root_class->ht_load_from_params(%pars);
	my $root;
	eval { $root = $class->ht_swit_render($r, $tested); };
	$class->swit_die("render failed: $@", $r, $tested) if $@;

	$root->ht_merge_params(%pars) if $supr;
	$root->ht_render($stash, $r);
	return $stash;
}

sub ht_swit_update_die {
	my ($class, $err, $r, $tested, $args) = @_;
	$class->swit_die("Update exception: $err", $r, $tested);
}

sub ht_swit_die {
	my ($class, $func, @args) = @_;
	return $class->swit_failure($class->$func(@args));
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
	return $class->ht_swit_die('ht_swit_update_die', $err, $r, $tested);
}

sub ht_swit_validate_die {
	my ($class, $errs, $r, $root) = @_;
	$class->swit_die("ht_validate failed", $r, $root, $errs);
}

sub swit_update {
	my ($class, $r) = @_;
	my %args = %{ $r->param || {} };
	if ($r->body_status !~ 'End of file') {
		$args{ $r->upload($_)->name } = $r->upload($_) for $r->upload;
	}
		
	my $tested = $class->ht_root_class->ht_load_from_params(%args);
	my @errs = $tested->ht_validate;
	return $class->ht_swit_die('ht_swit_validate_die', \@errs, $r, $tested)
			if @errs;
	return $class->ht_swit_transactional_update($r, $tested, \%args);
}

1;

package Apache::SWIT::HTPage::Safe;
use base 'Apache::SWIT::HTPage';

sub swit_render {
	my ($class, $r) = @_;
	my $stash = $class->SUPER::swit_render($r);
	my $es = $r->param('swit_errors') or goto OUT;
	$class->ht_root_class->ht_error_render($stash, 'swit_errors', $es);
OUT:
	return $stash;
}

sub _encode_errors {
	my ($class, $errs) = @_;
	my $es = $class->ht_root_class->ht_encode_errors(@$errs);
	return "r?swit_errors=$es";
}

sub ht_swit_validate_die {
	my ($class, $errs, $r, $root) = @_;
	return $class->_encode_errors($errs);
}

sub ht_swit_update_die {
	my ($class, $msg, $r, $root) = @_;
	my $t = $root->CDBI_Class->table;
	return ($msg =~ /unique constraint "$t\_(\w+)_key"/)
			? $class->_encode_errors([ [ $1, 'unique' ] ])
			: shift()->SUPER::ht_swit_update_die(@_);
}

