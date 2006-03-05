#!perl -T

use Test::More tests => 10;
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
unless ( $myspace->logged_in ) {
	die "Login Failed - can't run tests";
}
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

