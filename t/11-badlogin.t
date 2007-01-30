#!perl -T

use Test::More tests => 1;
#use Test::More 'no_plan';

use WWW::Myspace;

my $myspace = new WWW::Myspace( "wmyw" . int(rand(100000)) . "wmyw",
	"afh" . int(rand(100000)) . "fds" );

warn $myspace->error . "\n";

ok( ( $myspace->error =~ /Login Failed.*username.*password/is ),
	"site_login bad username/password handling" );

