#!perl -T

#use Test::More tests => 24;
use Test::More 'no_plan';

use lib 't';
use TestConfig;

login_myspace;

my $myspace1 = $CONFIG->{'acct1'}->{'myspace'};
my $myspace2 = $CONFIG->{'acct2'}->{'myspace'};

# Generate "random" seed.
my $ident = "wmyw" . int(rand(100000)) . "wmyw";
my ( @friends, $res );

# Try to approve friend requests for acct1
#warn "Approving friend requests for acct1\n";
@friends = $myspace1->approve_friend_requests( "Thanks for the add!\n\n${ident}" );

# If there was a friend (or more) approved, pass.
if ( @friends ) {
	pass( 'Approve friends' )
} else { # Otherwise,
	# From acct2, delete acct1 as a friend.
	warn "Deleting acct2 as a friend\n";
	$myspace1->delete_friend( $CONFIG->{'acct2'}->{'friend_id'} );

	# Then send a friend request.
	# This generates "use of initialized value" warnings from
	# HTTP::Request::Form.
	warn "Sending friend request from acct2 to acct1\n";
	warn 'Ignore the following "Use of uninitialized value" errors'."\n";
	$myspace2->send_friend_request( $CONFIG->{'acct1'}->{'friend_id'} );

	# Now try to approve friend requests.
	warn "Approving friend request\n";
	@friends = $myspace1->approve_friend_requests( "Thanks for the add!\n\n${ident}" );

	# If we approved someone, pass. otherwise, fail.
	if ( @friends ) {
		pass( 'Approve friends' );
	} else {
		fail( 'Approve friends' );
	}
}

# Now see if we posted that comment.
warn "Checking for comment post\n";
$res = $myspace1->get_profile( $CONFIG->{'acct2'}->{'friend_id'} );

if ( $res->content =~ /${ident}/ ) {
	pass( 'approve_friend_requests posted comment' );
} else {
	fail( 'approve_friend_requests posted comment' );
}
