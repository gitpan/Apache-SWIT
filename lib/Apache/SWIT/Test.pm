use strict;
use warnings FATAL => 'all';

package Apache::SWIT::Test;
use base 'Class::Accessor', 'Class::Data::Inheritable';
use HTML::Tested::Test::Request;
use HTML::Tested::Test;
use Test::More;
use Carp;
use Data::Dumper;
use File::Slurp;
use Apache::TestRequest;
use WWW::Mechanize;
use X11::GUITest;

BEGIN {
	no strict 'refs';
	no warnings 'redefine';
	my $init_sub = HTML::Parser->can("init");
	*{ "HTML::Parser::init" } = sub {
		my $res = shift()->$init_sub(@_);
		$res->utf8_mode(1);
		return $res;
	};
}

__PACKAGE__->mk_accessors(qw(mech fake_request session));
__PACKAGE__->mk_classdata('root_location');
__PACKAGE__->mk_classdata('root_env_var');

sub do_startup {
	my ($class, $root_env_var) = @_;
	$class->root_env_var($root_env_var);
	$ENV{$root_env_var} = $ENV{SWIT_BLIB_DIR};
	my $sf = $ENV{SWIT_BLIB_DIR} . "/conf/startup.pl";
	{
		package main;
		local $0 = $sf;
		do $sf or Carp::confess "# Unable to do $sf: $@";
	};
}

sub new {
	my ($class, $args) = @_;
	confess "Please call do_startup first!" unless $class->root_env_var;
	$args ||= {};
	if ($ENV{SWIT_HAS_APACHE}) {
		$args->{mech} = WWW::Mechanize->new;
	}
	if ($args->{session_class}) {
		$args->{session} = $args->{session_class}->new;
	}
	return $class->SUPER::new($args);
}

sub new_guitest {
	my $self = shift()->new(@_);
	if ($self->mech) {
		eval "use Mozilla::Mechanize::GUITester";
		die "Unable to use Mozilla::Mechanize::GUITester: $@" if $@;
		my $m = Mozilla::Mechanize::GUITester->new(quiet => 1, visible => 0);
		$self->mech($m);
		$m->x_resize_window(800, 600);
	}
	return $self;
}

sub _direct_render {
	my ($self, $handler_class, %args) = @_;
	my $r = $self->fake_request || HTML::Tested::Test::Request->new;
	$r->set_params($args{param}) if $args{param};
	$r->pnotes('SWITSession', $self->session);
	return $handler_class->swit_render($r);
}

sub _do_swit_update {
	my ($self, $handler_class, $r) = @_;
	$r->pnotes('SWITSession', $self->session);
	my @res = $handler_class->swit_update($r);
	my $new_r = HTML::Tested::Test::Request->new;
	$new_r->parse_url($res[0]);
	$self->fake_request($new_r);
	return @res;
}

sub _make_test_request {
	my ($self, $args) = @_;
	my $r = HTML::Tested::Test::Request->new({
			_param => $args->{fields} });
	my $b = delete $args->{button};
	$r->param($b->[0], $b->[1]) if ($b);
	return $r;
}

sub _direct_update {
	my ($self, $handler_class, %args) = @_;
	my $r = $self->_make_test_request(\%args);
	return $self->_do_swit_update($handler_class, $r);
}

sub mech_get_base {
	my ($self, $loc) = @_;
	my $url = "http://" . Apache::TestRequest::hostport() . $loc;
	return $self->mech->get($url);
}

sub _mech_render {
	my ($self, $handler_class, %args) = @_;
	my $goto = $args{base_url};
	$goto = $self->root_location . "/" . $args{url_to_make} 
			if ($args{make_url});
	$self->mech_get_base($goto) if $goto;
	return $self->mech->content;
}

sub _mech_update {
	my ($self, $handler_class, %args) = @_;
	delete $args{url_to_make};
	my $b = delete $args{button};
	$args{button} = $b->[0] if $b;
	delete $args{fields}->{$_} for map { $_->name } grep { $_->readonly }
		$self->mech->current_form->inputs;
	$self->mech->submit_form(%args);
	return $self->mech->content;
}

sub _direct_ht_render {
	my ($self, $handler_class, %args) = @_;
	my $res = $self->_direct_render($handler_class, %args);
	return HTML::Tested::Test->check_stash(
			$handler_class->ht_root_class, $res, $args{ht});
}

sub _mech_ht_render {
	my ($self, $handler_class, %args) = @_;
	my $content = $self->_mech_render($handler_class, %args);
	return HTML::Tested::Test->check_text(
			$handler_class->ht_root_class, $content, $args{ht});
}

sub _direct_ht_update {
	my ($self, $handler_class, %args) = @_;
	my $r = $self->_make_test_request(\%args);
	HTML::Tested::Test->convert_tree_to_param(
			$handler_class->ht_root_class, $r, $args{ht});
	return $self->_do_swit_update($handler_class, $r);
}

sub _mech_ht_update {
	my ($self, $handler_class, %args) = @_;
	my $r = HTML::Tested::Test::Request->new({
			_param => $args{fields} });
	HTML::Tested::Test->convert_tree_to_param(
			$handler_class->ht_root_class, $r, $args{ht});
	$args{fields} = $r->_param;
	delete $args{ht};

	goto OUT unless $r->upload;

	if (my $form_number = $args{'form_number'}) {
		$self->mech->form_number($form_number);
	} elsif (my $form_name = $args{'form_name'}) {
		$self->mech->form_name($form_name);
	}
	my $form = $self->mech->current_form;
	confess "Form method is not POST" if $form->method ne "POST";
	confess "Form enctype is not multipart/form-data"
	           if $form->enctype ne "multipart/form-data";

	for my $u ($r->upload) {
		my $i = $self->mech->current_form->find_input($u->name)
			or die "Unable to find input for " . $u->name;
		my $c = read_file($u->fh);
		$i->content($c);
		$i->filename($u->filename);
	}
OUT:
	return $self->_mech_update($handler_class, %args);
}

sub _make_test_function {
	my ($class, $handler_class, $op, $url) = @_; 
	return sub {
		my ($self, %a) = @_;
		$a{url_to_make} = $url;
		my $f = $self->mech ? "_mech_$op" : "_direct_$op";
		return $self->$f($handler_class, %a);
	};
}

sub make_aliases {
	my ($class, %args) = @_;
	my %trans = (r => 'render', u => 'update');
	while (my ($n, $v) = each %args) {
		no strict 'refs';
		while (my ($f, $t) = each %trans) {
			my $func = "$n\_$f";
			$func =~ s/\//_/g;
			my $url = "$n/$f";
			*{ "$class\::$func" } = 
				$class->_make_test_function($v, $t, $url);
			*{ "$class\::ht_$func" } = 
				$class->_make_test_function($v
						, "ht_$t", $url);
		}
		my $r_func = "ht_$n\_r";
		$r_func =~ s/\//_/g;
		*{ "$class\::ok_$r_func" } = sub {
			my $res = is_deeply([ shift()->$r_func(@_) ], []);
			carp('#') unless $res;
			return $res;
		};
	}
}

sub ok_follow_link {
	my ($self, %arg) = @_;
	$self->with_or_without_mech_do(1, sub {
		isnt($self->mech->follow_link(%arg), undef)
			or carp('# Unable to follow: ' . Dumper(\%arg)
				. "in\n" . $self->mech->content);
	});
}

sub ok_get {
	my ($self, $uri, $status) = @_;
	$status ||= 200;
	$self->with_or_without_mech_do(1, sub {
		$uri = $self->root_location . "/$uri" unless ($uri =~ /^\//);
		$self->mech_get_base($uri);
		is($self->mech->status, $status)
			or carp("# Unable to get: $uri");
	});
}

sub content_like {
	my ($self, $qr) = @_;
	$self->with_or_without_mech_do(1, sub {
		like($self->mech->content, $qr) or diag(Carp::longmess());
	});
}

sub with_or_without_mech_do {
	my ($self, $m_tests_cnt, $m_test, $d_tests_cnt, $d_test) = @_;
SKIP: {
	if ($self->mech) {
		$m_test->($self) if $m_test;
		skip "Not in direct test", $d_tests_cnt if $d_tests_cnt;
	} else {
		$d_test->($self) if $d_test;
		skip "Not in apache test", $m_tests_cnt;
	}
};
}

sub reset_db_table_from_class {
	my ($self, $dbc) = @_;
	$dbc->retrieve_all->delete_all;
	$dbc->db_Main->do("alter sequence ". $dbc->sequence ." restart with 1");
}

1;
