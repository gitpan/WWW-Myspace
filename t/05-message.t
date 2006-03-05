#!perl -T
#---------------------------------------------------------------------
# Test Message.pm
# $Id: 05-message.t,v 1.1 2006/02/28 09:40:04 grant Exp $

use Test::More tests => 18;
#use Test::More 'no_plan';

use lib 't';
use TestConfig;
use WWW::Myspace::Message;

login_myspace or die "Login Failed - can't run tests";


#diag( "Testing WWW::Myspace::Message $WWW::Myspace::Message::VERSION, Perl $], $^X" );

# First test the send_message method in WWW::Myspace
# Send a message
$response = "";
$response = $CONFIG->{'acct1'}->{'myspace'} ->send_message(
	$CONFIG->{'acct2'}->{'friend_id'},
	"Hi", 'Just saying hi.\n\n'.
	'Hope all is well.' );

if ( ( $response =~ /^P/ ) || ( $response eq 'FC' ) ) { $response = 'P' }

is( $response, 'P', 'Send Message' );

# For now to test read_message we use a specific message. We really
# should send one then try to read it.
my $mr = $CONFIG->{'acct2'}->{'myspace'}->read_message( 29026911 );

is( $mr->{from}, '48439059', "read_message From" );
is( $mr->{subject}, 'Hi', "read_message Subject" );
is( $mr->{date}, 'Feb 28, 2006 1:20 AM', "read_message Date" );
is( $mr->{body}, "Just saying hi.\n\nHope all is well.", "read_message Body" );


# Now test Message.pm
my $message = new WWW::Myspace::Message( $CONFIG->{'acct1'}->{'myspace'} );

$message->subject( "Hello" );

cmp_ok( $message->subject, "eq", 'Hello', "Message Subject" );

my $mymessage = 'This is a message from Message.\n\n- Me';

$message->body( $mymessage );

cmp_ok( $message->body, "eq", $mymessage, "Message Body" );

$message->friend_ids( $CONFIG->{'acct2'}->{'friend_id'} );
@friends = $message->friend_ids;

cmp_ok( $friends[0], "==", $CONFIG->{'acct2'}->{'friend_id'},
	"Friends to message" );

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
cmp_ok( $friends[0], '==', $CONFIG->{'acct2'}->{'friend_id'}, 
	'Exclusions list should have a friend' );
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
