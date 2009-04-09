package DBIx::Retry;
use warnings;
use strict;
use DBI;
use Readonly;
use Carp;
use version; our $VERSION = qv('0.0.3');

Readonly my $wait => 1;
Readonly my $retry => 10;

# Support a standard looking DBI->connect
sub connect {
	my ($class, $dsn, $user, $pass, $attr) = @_;

	# Add a default HandleError to show DBI string
	$attr ||= {};
	if (!exists($attr->{HandleError})) {
		$attr->{HandleError} = sub {
			my ($msg, $dbh, $first) = @_;
			# local $Carp::CarpLevel = 1;
			croak "DBIx::Retry Error - dsn=$dsn, message=$msg";
		};
	}

	my $self = bless {
		dsn => $dsn,
		user => $user,
		pass => $pass,
		attr => $attr,
	}, ref($class) || $class;
	$self->_reconnect;
	return $self;
}

# Force a reconnect to the database
sub _reconnect {
	my ($self) = @_;
	delete $self->{dbh};
	$self->{dbh} = DBI->connect(
		$self->{dsn},
		$self->{user},
		$self->{pass},
		$self->{attr},
	);
}

# Internal method to _try a connection
sub _try {
	my ($self, $cmd) = @_;
	my $count = 0;
	while (1) {
		$count++;
		my $ret = eval { no strict; my $tmp = $cmd->(); $tmp };

		# Try again
		if ($@ =~ /lock/) {
			if ($count > $retry) {
				die "DBI RETRY EXCEEDED - $self->{dsn} - $@";
			}
			sleep $wait;
			$self->_reconnect;
		}

		# Other error
		elsif ($@) {
			die "DBI ERROR - $@";
		}

		# Success !
		else {
			return $ret;
		}
	}
}

# Inform the user...
sub prepare {
	croak "Prepare not supported, use prepare_execute";
}

# 
sub prepare_execute {
	my ($self, $sql, @params) = @_;
	return $self->_try(sub {
		my $sth = $self->{dbh}->prepare($sql);
		$sth->execute(@params);
		return $sth;
	});
}

sub do {
	my ($self, $sql, $attr, @params) = @_;
	return $self->_try(sub {
		return $self->{dbh}->do($sql, $attr, @params);
	});
}

sub begin_work {
	my ($self) = @_;
	$self->{dbh}->begin_work;
}

sub rollback {
	my ($self) = @_;
	$self->{dbh}->rollback;
}

sub commit {
	my ($self) = @_;
	$self->{dbh}->commit;
}

sub disconnect {
	my ($self) = @_;
	$self->{dbh}->disconnect;
}

sub func {
	my ($self, @rest) = @_;
	return $self->{dbh}->func(@rest);
}

1;
