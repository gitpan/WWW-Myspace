#!perl -T

#use Test::More tests => 11;
use Test::More 'no_plan';
use Data::Dumper;

use lib 't';
use TestConfig;
login_myspace or die "Login Failed - can't run tests";
require_ok( 'Config::General' );
require_ok( 'IO::Prompt' );
require_ok( 'List::Compare' );
require_ok( 'Math::Round' );
require_ok( 'Params::Validate' );
require_ok( 'Scalar::Util' );

# create valid myspqce object
my $myspace = $CONFIG->{'acct1'}->{'myspace'};

isa_ok($myspace, 'WWW::Myspace');

use WWW::Myspace::FriendAdder;
my $adder = WWW::Myspace::FriendAdder->new($myspace, { 
    config_file => 't/friend_adder.cfg', 
    interactive => 3, 
    config_file_format => 'CFG'
    } 
);
isa_ok($adder, 'WWW::Myspace::FriendAdder');

my $config_file = 't/friend_adder.cfg';
ok (-e $config_file, 'found adder config file');

my $params = $adder->return_params();
ok ($params->{'max_attempts'} == 9999, 'max_attempts param set');
ok ($params->{'interactive'}  == 3,    'interactive param set');

# create object without arguments
$adder = WWW::Myspace::FriendAdder->new($myspace);

$params = $adder->return_params();
ok ($params->{'interactive'}  == 1,    'interactive param set to default');

# we want it to die here
my $eval = eval { $adder = WWW::Myspace::FriendAdder->new($myspace, 'foo') };

unless ($eval) {
    pass('Excellent.  It croaks on bad params');
}
else {
    fail('Oops.  Doesn\'t croak on bad params');
}

# Test YAML config and single hashref options setting
$adder = WWW::Myspace::FriendAdder->new( { 
	myspace => $myspace,
    config_file => 't/friend_adder.yml', 
    interactive => 4,
    config_file_format => 'YAML'
    } 
);

isa_ok($adder, 'WWW::Myspace::FriendAdder');

$config_file = 't/friend_adder.yml';
ok (-e $config_file, 'found adder YAML config file');

$params = $adder->return_params();
ok ($params->{'max_attempts'} == 9988, 'max_attempts param set');
ok ($params->{'interactive'}  == 4,    'interactive param set');
ok ($adder->{'config_file_format'} eq "YAML", 'Config file format correct' );