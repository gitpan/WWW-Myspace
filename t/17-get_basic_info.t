#!perl -T

use Test::More tests => 6;  # SEE FOREACH LOOP BLOW
#use Test::More 'no_plan';

use lib 't';
use TestConfig;
login_myspace or die "Login Failed - can't run tests";

my $myspace = $CONFIG->{acct1}->{myspace}; # For sanity

my ( %info ) = $myspace->get_basic_info( $CONFIG->{acct1}->{friend_id} );
foreach $key ( keys( %info ) ) {
    warn "$key: $info{$key}\n";
}

# If you change the number of keys here, change the number of tests above.
foreach my $key ( 'country', 'cityregion', 'headline', 'age', 'gender', 'lastlogin' ) {
    ok( $info{"$key"}, "get_basic_info got $key" );
}
