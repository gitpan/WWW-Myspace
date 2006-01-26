#!perl -T

use Test::More tests => 4;

BEGIN {
	use_ok( 'WWW::Myspace' );
	use_ok( 'WWW::Myspace::Message' );
	use_ok( 'WWW::Myspace::Comment' );
	use_ok( 'WWW::Myspace::FriendChanges' );
}

diag( "Testing WWW::Myspace $WWW::Myspace::VERSION, Perl $], $^X" );
