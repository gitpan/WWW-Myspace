#!perl -T

use Test::More tests => 1;
#use Test::More 'no_plan';

use lib 't';
use TestConfig;
login_myspace or die "Login Failed - can't run tests";

my $myspace = $CONFIG->{acct1}->{myspace}; # For sanity

SKIP: {
	skip "Not logged in", 1 unless $CONFIG->{login};

	my $result = $myspace->post_blog(
			subject => "Testing",
			message => "Hi there, sorry if you're reading this.",
			testing => 1, # Skips confirmation so blog doesn't post.
		);
	
	if ( $myspace->error ) {
		warn $myspace->error . "\n";
		warn "\n\n".$myspace->current_page->content;
	}
	
	ok( $result, "post_blog returns positive success code" );
}