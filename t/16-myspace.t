#!perl -T

use strict;
use warnings;
use Test::More;
use WWW::Myspace;

plan tests => 14;

my $myspace     = WWW::Myspace->new( auto_login => 0);
my $choclair    = 78557157;
my $private_id  = 13098613;
my $invalid_id  = 140854226;

can_ok( $myspace, '_regex' );
can_ok( $myspace, '_apply_regex' );
can_ok( $myspace, 'is_private' );
can_ok( $myspace, 'is_invalid' );

foreach my $regex ('is_private', 'is_invalid', 'friend_id' ) {
    ok ( $myspace->_regex( $regex ), "regex returned for $regex" );
}

ok ( $myspace->is_invalid( friend_id => $invalid_id ), "this profile disabled");

my $res = $myspace->get_profile( $choclair );
ok( $res, 'fetched Choclair page');

ok ( !$myspace->is_invalid( page => $res ), "choclair page not disabled");

my $public = $myspace->is_private( page => $res );
ok ( !$public, "choclair profile isn't private");

my $private = $myspace->is_private( friend_id => $private_id );

unless ( $private ) {
    diag("there might be a problem with the is_private method");
}

my $friend_id_regex = $myspace->_regex( 'friend_id' );

my $friend_id = undef;

if ( $res->content =~ $friend_id_regex ) {
    $friend_id = $1;
}

cmp_ok ($friend_id, '==', $choclair, "correct friend_id returned");

# reset the page in memory
$myspace->get_profile( $choclair );
my $friend_id_myspace = $myspace->friend_id;
cmp_ok ($friend_id_myspace, '==', $choclair, "correct friend_id returned");

my $friend_from_regex = $myspace->_apply_regex(
    regex => 'friend_id',
    page  => $res,
);
cmp_ok ($friend_from_regex, '==', $choclair, "correct friend_id returned");


