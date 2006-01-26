#!perl -T

#use Test::More tests => 24;
use Test::More 'no_plan';

use lib 't';
use TestConfig;
login_myspace;

# Make sure we've got two accounts and didn't accidentally use the
# same one twice.
cmp_ok( $CONFIG->{'acct1'}->{'myspace'}->my_friend_id, '!=',
	$CONFIG->{'acct2'}->{'friend_id'}, 'Verify friend ID' );

# Check friendID method.
cmp_ok( $CONFIG->{'acct1'}->{'myspace'}->my_friend_id, '==',
	$CONFIG->{'acct1'}->{'friend_id'}, 'Verify friend ID' );

