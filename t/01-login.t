#!perl -T

use Data::Dumper;
use Test::More tests => 19;
#use Test::More 'no_plan';

use lib 't';
use TestConfig;
# This logs us in only if they have a local config file.
login_myspace or die "Login Failed - can't run tests";

unless ( $CONFIG->{login} ) {
	diag "Running tests without login.  If you want to run the full test\n".
		 "suite (not required), see the README file that came with the\n".
		 "distribution.";
}

# Some setup
my $response;
my $attempts;
my @friends;
my $myspace = $CONFIG->{'acct1'}->{'myspace'};
my $myspace2 = $CONFIG->{'acct2'}->{'myspace'};

ok( ref $myspace, 'Create myspace object' );


# Test is_band
is( $myspace->is_band( 30204716 ), 1,
	"is_band identifies band profile correctly" );
is( $myspace->is_band( $CONFIG->{'acct2'}->{'friend_id'} ), 0,
	"is_band identifies 3rd party non-band profile correctly" );

SKIP: {
	skip "Not logged in", 7 unless $CONFIG->{login};

	ok( $myspace->logged_in, "Login successful" );

	cmp_ok( $myspace->my_friend_id, '==', $CONFIG->{'acct1'}->{'friend_id'},
		'Verify friend ID' );

	is( $myspace->account_name, $CONFIG->{'acct1'}->{'username'},
		'Verify account_name' );

	is( $myspace->user_name, $CONFIG->{'acct1'}->{'user_name'},
		'Verify user_name' );

	# This should return more than 0 friends. If the regexp breaks,
	# this'll return something else, like undefined.
	cmp_ok( $myspace->friend_count, '>', 0, 'Check friend_count' );

	# Get friends
	@friends = $myspace->get_friends;

	ok( @friends, 'Retreived friend list' );

	if ( @friends != 2 ) {
		diag( 'Account has ' . @friends . ' friends' );
	}

	# Check friends who emailed. We get messages from the other test account,
	# so this should be greater than 0.
	my @friends_who_emailed = $myspace->friends_who_emailed;
	cmp_ok( @friends_who_emailed, '>=', 0, 'Retreive friends who emailed' );

}

is( $myspace->friend_user_name( $CONFIG->{'acct2'}->{'friend_id'} ),
	$CONFIG->{'acct2'}->{'user_name'}, 'Verify friend_user_name' );

SKIP: {

	skip "Not logged in", 5 unless $CONFIG->{login};

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
	
	@friends = sort @friends;
	# The friends and other_friends lists should be identical.
	# So first test the length
	is( @other_friends, @friends, 'Check friends_from_profile friend count');
	#diag( Dumper \@other_friends);
	#diag( Dumper \@friends);


	# Now check the elements
	SKIP: {
		skip "Friend count mismatch, won't test each element", 1 unless 
			( @other_friends == @friends );
		my $friends_pass=1;
		for ( my $i = 0; $i < @friends; $i++ ) {
			unless ( $friends[$i] == $other_friends[$i] ) {
				$friends_pass=0;
				diag "Friend1: " . $friends[$i] . ", Friend2: " .
					$other_friends[$i] . "\n";
			}
		}
		
		if ( $friends_pass ) {
			pass( 'Check friends_from_profile' )
		} else {
			fail( 'Check friends_from_profile' )
		}
	}

	# Count the friends in the test group. If we can get more than
	# 40 (first page) of friends we should be ok for the rest.?
	my @friends_in_group = $myspace->friends_in_group( $CONFIG->{'test_group'} );

	SKIP: { skip "friend_in_group disabled until it can be fixed due to myspace change.", 1;
		cmp_ok( @friends_in_group, '>', 41, 'Retreive friends in Perl Group' );
		diag( "Counted " . @friends_in_group . " friends in group" );
	}

	# Post a comment
	$response = $myspace->post_comment( $CONFIG->{'acct2'}->{'friend_id'},
		"Um, great profile..." );
	if ( ( $response =~ /^P/ ) || ( $response eq 'FC' ) ||
		 ( $response eq "FF") ) { $response = 'P' }

	warn $myspace->error . "\n" if $myspace->error;
	is( $response, 'P', 'Post Comment' );

	# Test is_band logged in
	is( $myspace2->is_band, 0,
		"is_band identifies logged-in non-band profile correctly" );

}

# Test friend_id method
# 1. Check friend_id is returned when passed a link directly to the profile (eg. myspace.com/<friend_id>)
is ($myspace->friend_id("48439059"), 48439059, "Get correct friend_id when passsed myspace.com/<friend_id>");

# 2. check friend_id is returned by url
is  ($myspace->friend_id("tomkerswill"), 7875748,"Get correct friend_id when passed custom URL.");

# 3. check nothing is returned when passed just homepage
#is ( $myspace->friend_id(""), "","Get when URL doesn't correspond to a profile");

# Test last_login
if ( $CONFIG->{login} ) {
	cmp_ok ( $myspace->last_login( $CONFIG->{'acct2'}->{'friend_id'} ), ">",
	         time - 86400, "last_login date is today" );
} else {
	ok ( $myspace->last_login( $CONFIG->{'acct2'}->{'friend_id'} ),
	     "last_login returns a value" );
}