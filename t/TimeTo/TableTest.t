#!/usr/bin/perl

use strict;
use warnings;
use Test::More 'no_plan';
use Test::Deep;
use DateTime;
use Data::Dumper;
use lib '../../lib';
use TimeTo::Table;

my $dt_pat = qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/;

### Set up a DB
my $testdb = "./TimeTableTest.db";
my $tt = reinitAndConnect( $testdb );

### Testing today()
my @entries = ({project => "proj1"}, 
			   {project => "proj2"}, 
			   {project => "proj3"}
			  );
for my $entry (@entries) {
	$tt->insert($entry);
	sleep(1);
}
$DB::single=1;
my @today = $tt->today();
is( $#entries, $#today, "today() returned right number of records" );
for (my $i=0; $i<@entries-1; $i++) {
	cmp_deeply(
		$today[$i],	
		{
			project => $entries[$i]->{project},
			start => re($dt_pat),
			stop => re($dt_pat),
			category => undef
		},
		"record $i ok"
	);
}
cmp_deeply(
	$today[$#today],	
	{
		project => $entries[$#entries]->{project},
		start => re($dt_pat),
		stop => undef,
		category => undef
	},
	"record $#entries ok"
);


### Rewrite these!
if (0) {
diag( "Sequential inserts" );
for (my $i = 0; $i < 5; $i++) {
	$tt->insert({
		project => "project$i",
	});
	sleep(1);
}
diag( "Resulting table:" );
dump_db();

diag( "Inserting with category" );
$tt->insert({ project => "project3", category => "foo" });
sleep(1);
diag( "Inserting same project without category");
$tt->insert({ project => "project3" });
diag( "Resulting table:" );
dump_db();

diag( "Checking non-tail insert" );
sleep(1);
$tt->insert({project => "pastcheck", category => "catA"});
sleep(1);
my $now = DateTime->now();
sleep(1);
$tt->insert({ project => "pastcheck", category => "catB"});
diag( "Table with chronological insert:");
dump_db();
$tt->insert({ project => "pastcheck" }, $now);
diag( "Resulting table:" );
dump_db();
diag( "And continuing chronological inserts:" );
sleep(1);
$tt->insert({ project => "pastcheck" });
dump_db();

diag( "Checking insert to exisiting times" );
$tt->insert({ project => "pastcheck"}, $now);
$tt->insert({ project => "newproj"}, $now);
dump_db();

diag( "Checking most_recent return:" );
print Dumper( $tt->most_recent );
print "\n";

diag( "Edit most recent" );
$tt->edit( $tt->most_recent, { project => 'newproj', category => 'newcat' } );
dump_db();

diag( "Attempting illegal inserts" );
eval {
	$tt->insert({});
};
if ($@) {
	warn $@;
}
eval {
	$tt->insert({category=>'foo'});
};
if ($@) {
	warn $@;
}

#print Dumper( $tt->most_recent );
}

sub dump_db {
	print "***\n";
	print `echo "select * from Timespan;" | sqlite3 $testdb`;
	print "***\n\n";
}

sub reinitAndConnect {
	my ($testdb) = @_;
	diag( "Removing and recreating $testdb" );
	`rm $testdb`;
	`cat ../../create.sql | sqlite3 $testdb`;
	diag( "Connecting" );
	my $tt = TimeTo::Table->new();
	$tt->connect( "dbi:SQLite:$testdb", "Timespan" );
	return $tt;
}

