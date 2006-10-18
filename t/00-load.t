#!perl -T

use Test::More tests => 7;

BEGIN {
	use_ok( 'WWW::Myspace' );
	use_ok( 'WWW::Myspace::Message' );
	use_ok( 'WWW::Myspace::Comment' );
	use_ok( 'WWW::Myspace::FriendChanges' );
	use_ok( 'WWW::Myspace::FriendAdder' );
	use_ok( 'WWW::Myspace::MyBase' );
	use_ok( 'WWW::Myspace::Data' );
}

diag( "Testing WWW::Myspace $WWW::Myspace::VERSION, Perl $], $^X" );
