#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'WWW::Myspace' );
}

diag( "Testing WWW::Myspace $WWW::Myspace::VERSION, Perl $], $^X" );
