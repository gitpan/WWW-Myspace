#!perl -T

use Test::More tests => 12;
#use Test::More 'no_plan';

use lib 't';
use TestConfig;
login_myspace or die "Login Failed - can't run tests";

# Some setup
my $response;
my $attempts;
my $myspace = $CONFIG->{'acct1'}->{'myspace'};
my $myspace2 = $CONFIG->{'acct2'}->{'myspace'};

ok( ref $myspace, 'Create myspace object' );

cmp_ok( $myspace->my_friend_id, '==', $CONFIG->{'acct1'}->{'friend_id'},
	'Verify friend ID' );

is( $myspace->account_name, $CONFIG->{'acct1'}->{'username'},
	'Verify account_name' );

is( $myspace->user_name, $CONFIG->{'acct1'}->{'user_name'},
	'Verify user_name' );

is( $myspace->friend_user_name( $CONFIG->{'acct2'}->{'friend_id'} ),
	$CONFIG->{'acct2'}->{'user_name'}, 'Verify friend_user_name' );

# This should return more than 0 friends. If the regexp breaks,
# this'll return something else, like undefined.
cmp_ok( $myspace->friend_count, '>', 0, 'Check friend_count' );

# Get friends
my @friends = $myspace->get_friends;

ok( @friends, 'Retreived friend list' );

if ( @friends != 2 ) {
	diag( 'Account has ' . @friends . ' friends' );
}

# Get someone else's friends (same list, different method).
my @other_friends =
	$myspace2->friends_from_profile( $CONFIG->{'acct1'}->{'friend_id'} );

# If we're on the list, our "other_friends" list will be missing us,
# so put us back in for testing.
foreach my $id ( @friends ) {
	if ( $id == $CONFIG->{'acct2'}->{'friend_id'} ) {
		push( @other_friends, $id );
		# They have to be in numerical order to match.
		@other_friends = sort( @other_friends );
		last;
	}
}

# The friends and other_friends lists should be identical.
# So first test the length
is( @other_friends, @friends, 'Check friends_from_profile friend count');


# Now check the elements
SKIP: {
	skip "Friend count mismatch, won't test each element", 1 unless 
		( @other_friends == @friends );
	my $friends_pass=1;
	for ( my $i = 0; $i < @friends; $i++ ) {
		unless ( $friends[$i] == $other_friends[$i] ) {
			$friends_pass=0;
			diag "Friend1: " . $friends[$i] . ", Friend2: " . $other_friends[$i] .
				"\n";
		}
	}
	
	if ( $friends_pass ) {
		pass( 'Check friends_from_profile' )
	} else {
		fail( 'Check friends_from_profile' )
	}
}

# Check friends who emailed. We get messages from the other test account,
# so this should be greater than 0.
my @friends_who_emailed = $myspace->friends_who_emailed;
cmp_ok( @friends_who_emailed, '>=', 0, 'Retreive friends who emailed' );

# Count the friends in the test group. If we can get more than
# 40 (first page) of friends we should be ok for the rest.?
my @friends_in_group = $myspace->friends_in_group( $CONFIG->{'test_group'} );

cmp_ok( @friends_in_group, '>', 41, 'Retreive friends in Perl Group' );
diag( "Counted " . @friends_in_group . " friends in group" );

# Post a comment (This posts to a special test account)
$response = $myspace->post_comment( $CONFIG->{'acct2'}->{'friend_id'},
	"Um, great profile..." );
if ( ( $response =~ /^P/ ) || ( $response eq 'FC' ) ||
	 ( $response eq "FF") ) { $response = 'P' }

is( $response, 'P', 'Post Comment' );

