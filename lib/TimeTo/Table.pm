package TimeTo::Table;
use strict;
use warnings;
use TimeTo::DB;
use DateTime;

sub new {
	my $class = shift;
	my $self  = {};
	$self->{STORAGE} = undef;
	$self->{RESERVED_COLS} = { start => 1, stop => 1 };
	$self->{MAND_COLS} = {};
	$self->{OPT_COLS} = {};
	bless ($self, $class);
	return $self;
}

#sub create {
#	my $self = shift;
#
#}

sub connect {
	my $self = shift;
	my ($dbi_dsn, $table) = @_;
	$self->{STORAGE} = TimeTo::DB->connect($dbi_dsn)->resultset($table);
	my $rs = $self->{STORAGE}->result_source( );
	for my $col (grep {!$self->{RESERVED_COLS}->{$_}} $rs->primary_columns()) {
		$self->{MAND_COLS}->{$col} = 1;
	}
	for my $col (grep {!$self->{RESERVED_COLS}->{$_} && !$self->{MAND_COLS}->{$_}} $rs->columns()) { 
		$self->{OPT_COLS}->{$col} = 1;
	}
}

## sub insert( \%entry, $time )
# Inserts entry chronologically into table.
#
# Creates a new row in the table with column values as defined in %entry. 
# Columns that are or are part of primary keys must be defined.
# %entry should not define 'start' or 'stop'.
# If no $time is given, entry is recorded at current time.
sub insert {
	my $self = shift;
	my ($args, $time) = @_;
	for my $col (keys %{$self->{MAND_COLS}}) {
		die "$col must be specified for insert.\n" if !defined( $args->{$col} );
	}
	$time = DateTime->now() if !defined( $time );
	$args->{start} = $time;
	my $newrec;
	eval {
		$newrec = $self->{STORAGE}->create($args);
	};
	if ($@) {
		warn $@;
		return;
	}

	my $prev = $self->_get_prev( $time );
	if ($prev) {
		$prev->stop( $newrec->start() );
		$prev->update();
	}

	my $next = $self->_get_next( $time );
	if ($next) {
		$newrec->stop( $next->start() );
	}

	$DB::single =1;
	for my $optcol (keys %{$self->{OPT_COLS}}) {
		if (!$newrec->get_column($optcol)) {
			my $prev_prim = $self->_get_prev_primary( $time, $newrec );
			if ($prev_prim) {
				$newrec->set_column( $optcol => $prev_prim->get_column($optcol) );
			}
		}
	}

	$newrec->update();
}

## sub edit( $entry, \%edits )
# Edits the entry with the values in %edits.
#
# 
sub edit {
 	my $self = shift;
	my ($entry, $edits) = @_;
	return $self->{STORAGE}->search($entry)->update( $edits );
}

## sub most_recent()
#
sub most_recent {
	my $self = shift;
	my $match = shift || {};
	my $entries = $self->{STORAGE}->search(
		$match,
		{ order_by => 'start DESC' }
	);
	my $entry = $entries->single();
	if ($entry) {
		my %data = $entry->get_columns();
		return \%data;
	}
}


sub today {
	my ($self) = @_;
	my $now = DateTime->now();
	$now->set_time_zone( 'local' );
	$now->set( 	hour => 0,
				minute => 0,
				second => 0
			);
	$now->set_time_zone( 'UTC' );
	my $entries = $self->{STORAGE}->search(
		{ start => {'>', $now->datetime()} },
		{ order_by => 'start ASC' }
	);
	my @ret;
	while (my $entry = $entries->next()) {
		my %data = $entry->get_columns();
		push @ret, \%data;
	}
	return @ret;
}


sub _get_prev {
	my $self = shift;
	my $start = shift;
	my $prevs = $self->{STORAGE}->search(
		{ start	=> {'<', $start}, },
		{ order_by => 'start DESC' }
	);
	return $prevs->single();
}

sub _get_prev_primary {
	my $self = shift;
	my ($start, $nr) = @_;
	my $entry = { start => {'<', $start},};
	for my $prim (keys %{$self->{MAND_COLS}}) {
		$entry->{$prim} = $nr->get_column($prim);
	}
	my $prevs = $self->{STORAGE}->search(
		$entry,
		{ order_by => 'start DESC' }
	);
	return $prevs->single();
}

sub _get_next {
	my $self = shift;
	my $start = shift;
	my $nexts = $self->{STORAGE}->search(
		{ start	=> {'>', $start}, },
		{ order_by => 'start ASC' }
	);
	return $nexts->single();
}

1;
