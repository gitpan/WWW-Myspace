#!perl -T

use Test::More tests => 3; 
#use Test::More 'no_plan';
use Data::Dumper;
use WWW::Myspace::MyBase;

use lib 't';

# create an object without params
use WWW::Myspace::FriendAdder;
my $adder = WWW::Myspace::FriendAdder->new();

isa_ok($adder, 'WWW::Myspace::FriendAdder');
my %config = (
    'config_file'        => 't/friend_adder.cfg', 
    'config_file_format' => 'CFG',
);

$adder = WWW::Myspace::FriendAdder->new( \%config );
isa_ok($adder, 'WWW::Myspace::FriendAdder');

use TestConfig;
login_myspace or die "Login Failed - can't run tests";

# create valid myspqce object
my $myspace = $CONFIG->{'acct1'}->{'myspace'};

$adder = WWW::Myspace::FriendAdder->new( $myspace );
isa_ok($adder, 'WWW::Myspace::FriendAdder');