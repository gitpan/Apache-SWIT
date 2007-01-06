use strict;
use warnings FATAL => 'all';

package Apache::SWIT::DB::Connection;
use base 'Class::Data::Inheritable', 'Class::Accessor';
use DBIx::ContextualFetch;
use Carp;

__PACKAGE__->mk_classdata('Instance');
__PACKAGE__->mk_classdata('DBIArgs', { PrintError => 0
			, RaiseError => 1, AutoCommit => 1,
			RootClass => 'DBIx::ContextualFetch', });

__PACKAGE__->mk_accessors(qw(db_handle pid));

sub instance {
	my ($class, $handle) = @_;
	my $self = $class->Instance;
	return $self if $self && $self->pid == $$;

	$self->db_handle->{InactiveDestroy} = 1 if $self;

	$handle ||= $class->connect;
	$self = $class->new({ db_handle => $handle, pid => $$ });
	$class->Instance($self);
	return $self;
}

sub connect {
	my $class = shift;
	my $dbn = $ENV{APACHE_SWIT_DB_NAME} 
			or confess "# No \$ENV{APACHE_SWIT_DB_NAME} given!";
	my $dbh = DBI->connect("dbi:Pg:dbname=$dbn"
				, undef, undef, $class->DBIArgs)
		or die "Unable to connect to $dbn db";
	return $dbh;
}

1;
