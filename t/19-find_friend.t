#!perl -T

#use Test::More 'no_plan';
use Test::More tests => 1;
use strict;

use WWW::Myspace;

use lib 't';
use TestConfig;
#login_myspace or die "Login Failed - can't run tests";

# Get myspace object
my $myspace = new WWW::Myspace( auto_login => 0 );

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