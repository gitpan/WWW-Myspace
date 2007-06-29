#!perl -T

use Test::More tests => 1;
#use Test::More 'no_plan';

use lib 't';
use TestConfig;
login_myspace or die "Login Failed - can't run tests";

my $myspace = $CONFIG->{acct1}->{myspace}; # For sanity

SKIP: {
	skip "Not logged in", 1 unless $CONFIG->{login};

	my $result = $myspace->post_bulletin(
			subject => "Testing",
			message => "Hi there, sorry if you got this.",
			testing => 1,
		);
	
	if ( $myspace->error ) {
		warn $myspace->error . "\n";
#		warn "\n\n".$myspace->current_page->content;
	}
	
	ok( $result, "post_bulletin returns positive success code" );
}