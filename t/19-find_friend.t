#!perl -T

#use Test::More 'no_plan';
use Test::More tests => 2;
use strict;

use WWW::Myspace;

use lib 't';
use TestConfig;
#login_myspace or die "Login Failed - can't run tests";

# Get myspace object
my $myspace = new WWW::Myspace( auto_login => 0 );


# Try to find an account which doesn't exist
my @results = $myspace->find_friend( 'madeup@example.com' );
if ( $myspace->error )
{
    warn $myspace->error;
    fail( 'Search for a non-existent friend');
} else {
    my $num_results = @results;
    is ($num_results, 0, 'Search for a non-existent friend');
}


SKIP: {
    my $email = $CONFIG->{acct1}->{username};
    skip "find_friend_email not set in config", 1 unless $email;

    my ( $friend_id ) = $myspace->find_friend( $email );
    
    if ( $myspace->error ) {
       warn $myspace->error;
       fail( 'find_friend' );
    } else {
        is( $friend_id, $CONFIG->{acct1}->{friend_id}, 'find_friend' );
    }
}
