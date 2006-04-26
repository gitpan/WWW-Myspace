#!perl -T

#use Test::More 'no_plan';
use Test::More tests => 2;
use strict;

use WWW::Myspace;

use lib 't';
use TestConfig;
login_myspace or die "Login Failed - can't run tests";

# Get myspace object for clarity
my $myspace = $CONFIG->{'acct1'}->{'myspace'};

my @cool_new_people = $myspace->cool_new_people('US');

# Just make sure it returned more than 10 people.
cmp_ok( @cool_new_people, '>', 10, "cool_new_people returned more than 10 IDs" );

# Make sure they're all numbers
my $pass=1;
foreach my $id ( @cool_new_people ) {
	unless ( $id =~ /^[\d]+$/ ) { $pass = 0; warn "Invalid ID: $id\n" }
}

if ( $pass ) {
	pass( "cool_new_people ids are digits" )
} else {
	fail( "cool_new_people ids are digits" )
}