#!perl -T

use Test::More tests => 15;  # SEE FOREACH LOOP BLOW
#use Test::More 'no_plan';

use lib 't';
use TestConfig;
login_myspace or die "Login Failed - can't run tests";

my $myspace = $CONFIG->{acct1}->{myspace}; # For sanity

#individual profile
my ( %info ) = $myspace->get_basic_info( $CONFIG->{acct1}->{friend_id} );
#foreach $key ( keys( %info ) ) {
#    warn "$key: $info{$key}\n";
#}

# If you change the number of keys here, change the number of tests above.
foreach my $key ( 'country', 'cityregion', 'city', 'region','headline', 'age', 'gender', 'lastlogin' ) {
    ok( $info{"$key"}, "individual: get_basic_info $key : $info{\"$key\"}" );
}

#bandprofile
( %info ) = $myspace->get_basic_info( 3327112 );
# If you change the number of keys here, change the number of tests above.
foreach my $key ( 'country', 'cityregion', 'city', 'region','headline','profileviews', 'lastlogin' ) {
    ok( $info{"$key"}, "band: get_basic_info $key : $info{\"$key\"}" );
}
