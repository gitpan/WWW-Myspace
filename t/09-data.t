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

my $data = WWW::Myspace::Data->new();
 
isa_ok($data, 'WWW::Myspace::Data');

# my $time = ();
# 
# print "time is $time";
# 
# my $date_stamp = $data->date_stamp( 
#     { time_zone => 'America/Toronto', epoch => $time, }
# );
# 
# print $date_stamp;

