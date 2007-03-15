#!perl -T

use strict;
use warnings;
use Test::More;
use WWW::Myspace;

plan tests => 5;

my $myspace = WWW::Myspace->new( auto_login => 0);

my $choclair = 78557157;

my $res = $myspace->get_profile( $choclair );
ok( $res, 'fetched Choclair page');

my $friend_id_regex = $myspace->_regex( 'friend_id' );
ok ( $friend_id_regex, "regex returned" );

my $friend_id = undef;

if ( $res->content =~ $friend_id_regex ) {
    $friend_id = $1;
}

cmp_ok ($friend_id, '==', $choclair, "correct friend_id returned");

my $friend_id_myspace = $myspace->friend_id;
cmp_ok ($friend_id_myspace, '==', $choclair, "correct friend_id returned");

my $friend_from_regex = $myspace->_apply_regex(
    regex => 'friend_id',
    page  => $res,
);
cmp_ok ($friend_from_regex, '==', $choclair, "correct friend_id returned");
