#!perl -T

#use Test::More tests => 15;
use Test::More 'no_plan';
use Data::Dumper;

use lib 't';
use TestConfig;
login_myspace or die "Login Failed - can't run tests";
require_ok( 'Config::General' );
require_ok( 'IO::Prompt' );
require_ok( 'List::Compare' );
require_ok( 'Params::Validate' );
require_ok( 'Math::Round' );

# create valid myspqce object
my $myspace = $CONFIG->{'acct1'}->{'myspace'};

ok( ref $myspace, 'Create myspace object' );

use WWW::Myspace::FriendAdder;

my $adder = WWW::Myspace::FriendAdder->new($myspace, );
ok ( ref $adder, 'create adder object' );

my $config_file = 't/friend_adder.cfg';
ok (-e $config_file, 'found adder config file');

$adder->set_param( config => $config_file, max_attempts => 9999 );
my $params = $adder->return_params();
ok ($params->{'max_attempts'} == 9999, 'max_attempts param set');

