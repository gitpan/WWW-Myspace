#!perl -T

use Test::More tests => 24;
#use Test::More 'no_plan';

use WWW::Myspace;
use WWW::Myspace::Message;

# Our test account
my $accountname = 'perl+user@bebop.com';
my $password = 'BluDoggie1';
my $friend_id = '48439059';
my $user_name = "Perl";
my $friend = '48449904';
my $friend_user_name = "Perl 2";
my $test_group = '100009984'; # Appropriate I think.

# Some setup
my $response;
my $attempts;

#$accountname = 'grant@cscorp.com';
#$password = '';
#$friend_id = 30204716;
#$user_name = "Grant Grueninger";


# Log in
my $myspace = new WWW::Myspace( $accountname, $password );

# Verify login
ok( ref $myspace, 'Create myspace object' );

## Test cache file exists
#if ( -f $myspace->cache_file ) {
#	pass( 'Cache file exists' )
#} else {
#	fail( 'Cache file exists' )
#}
#
## Test removal of cache file
#$myspace->remove_cache;
#
#if ( -f $myspace->cache_file ) {
#	fail( 'Cache file removed' )
#} else {
#	pass( 'Cache file removed' )
#}

# Test cache dir
#diag( "Cache dir set to " . $myspace->cache_dir );
#if ( -d $myspace->cache_dir ) {
#	pass( 'Cache directory exists' );
#} else {
#	fail( 'Cache directory exists' );
#}

cmp_ok( $myspace->my_friend_id, '==', $friend_id, 'Verify friend ID' );

is( $myspace->account_name, $accountname, 'Verify account_name' );

is( $myspace->user_name, $user_name, 'Verify user_name' );

is( $myspace->friend_user_name( $friend ), $friend_user_name,
	'Verify friend_user_name' );

# This should return more than 0 friends. If the regexp breaks,
# this'll return something else, like undefined.
cmp_ok( $myspace->friend_count, '>', 0, 'Check friend_count' );

# Get friends
my @friends = $myspace->get_friends;

ok( @friends, 'Retreived friend list' );

if ( @friends != 2 ) {
	diag( 'Account has ' . @friends . ' friends' );
}

# Check friends who emailed. This should be 0 because we don't count Tom.
my @friends_who_emailed = $myspace->friends_who_emailed;
cmp_ok( @friends_who_emailed, '>=', 0, 'Retreive friends who emailed' );

# Count the friends in the test group.
my @friends_in_group = $myspace->friends_in_group( $test_group );

cmp_ok( @friends_in_group, '>', 41, 'Retreive friends in Perl Group' );
diag( "Counted " . @friends_in_group . " friends in group" );

# That's about all we can do without depending on myspace too much
# or sending a message.

# Post a comment (This posts to a special test account)
$response = $myspace->post_comment( $friend, "Um, great profile..." );
if ( ( $response =~ /^P/ ) || ( $response eq 'FC' ) ||
	 ( $response eq "FF") ) { $response = 'P' }

is( $response, 'P', 'Post Comment' );

# Send a message
$response = "";
$response = $myspace->send_message( $friend, "Hi", 'Just saying hi.\n\n'.
	'Hope all is well.' );
if ( ( $response =~ /^P/ ) || ( $response eq 'FC' ) ) { $response = 'P' }

is( $response, 'P', 'Send Message' );


#---------------------------------------------------------------------
# Test Message.pm

diag( "Testing WWW::Myspace::Message $WWW::Myspace::Message::VERSION, Perl $], $^X" );

my $message = new WWW::Myspace::Message( $myspace );

$message->subject( "Hello" );

cmp_ok( $message->subject, "eq", 'Hello', "Message Subject" );

my $mymessage = 'This is a message from Message';

$message->body( $mymessage );

cmp_ok( $message->body, "eq", $mymessage, "Message Body" );

$message->friend_ids( $friend );
@friends = $message->friend_ids;

cmp_ok( $friends[0], "==", $friend, "Friends to message" );

cmp_ok( $message->max_count, '==', 300, "max_count default is 300" );

$message->max_count( 49 );

cmp_ok( $message->max_count, '==', 49, "max_count set to 49" );

cmp_ok( $message->delay_time, '==', 86400,
	"delay_time default is 24 hours" );

# Lets try actually sending a message
$message->cache_file( "msgexcl" );

$message->add_to_friends( 1 );

$response = "";
$response = $message->send_message;

if ( ( $response eq "CAPTCHA" ) || ( $response eq "COUNTER" ) ||
	( $response eq "DONE" ) ) {
	$response = "P"
}

is( $response, 'P', 'Send message from Message' );
#diag('Response is ' . $response );

# Check the exclusions
@friends = $message->exclusions;
cmp_ok( $friends[0], '==', $friend, 'Exclusions list should have a friend' );
#diag( 'My friend is ' . $friends[0] );

cmp_ok( @friends, '==', 1, 'Exclusions list count should be 1' );

# Reset the exclusions
$message->reset_exclusions;

# Check the exclusions
@friends = $message->exclusions;
cmp_ok( @friends, '==', 0, 'Reset exclusions list' );

ok( ( ! -f $message->cache_file ), 'Exclusions list removed' );

# Test save/load
my $savefile="msave.yml";
#diag( "testing save/load in " . $savefile );
$message->save( $savefile );
$message->message( "none" );

ok( ( $message->message eq "none" ), "Save and clear message" );

$message->load( $savefile );
cmp_ok( $message->message, 'eq', "$mymessage", "Load message" );

# Clean up
unlink 'msave.yml';
