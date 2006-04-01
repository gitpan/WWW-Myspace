#!perl -T

use Test::More tests => 2;
#use Test::More 'no_plan';
use strict;
use Data::Dumper;

use lib 't';
use TestConfig;
login_myspace or die "Login Failed - can't run tests";
require_ok( 'WWW::Myspace::Data' );

# create valid myspqce object
my $myspace = $CONFIG->{'acct1'}->{'myspace'};

use WWW::Myspace::Data;

my $adder = WWW::Myspace::Data->new();
 
isa_ok($adder, 'WWW::Myspace::Data');

