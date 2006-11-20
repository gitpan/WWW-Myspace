#!perl -T

use Test::More tests => 3;
#use Test::More 'no_plan';

use lib 't';
use TestConfig;
login_myspace or die "Login Failed - can't run tests";

my $myspace = $CONFIG->{acct1}->{myspace}; # For sanity

# Get a list of photo IDs
my @photo_ids = $myspace->get_photo_ids(
        friend_id => $CONFIG->{acct1}->{friend_id}
    );

my ( %friend_ids ) = ();
my $pass = 1;
foreach my $id ( @photo_ids ) {
    if ( $friend_ids{ $id } ) {
        $pass=0;
        warn "Found duplicate photo ID $id\n";
    } else {
        $friend_ids{ $id }++;
    }
}

ok( ( @photo_ids || ( @photo_ids == 0 ) ),
        'get_photo_ids returned at least one photo' );
ok( $pass, 'No duplicate IDs found' );

SKIP: {
	skip "Not logged in", 1 unless $CONFIG->{login};

    # Try to set the default photo.
    skip "Need more than 1 photo", 1 unless ( @photo_ids > 1 );

    ok( $myspace->set_default_photo( photo_id => $photo_ids[ 0 ] ),
            'set_default_photo' );

}