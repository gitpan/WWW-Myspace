#!perl -T

#use Test::More tests => 24;
use Test::More 'no_plan';

use lib 't';
use TestConfig;

login_myspace;

my $myspace1 = $CONFIG->{'acct1'}->{'myspace'};
my $myspace2 = $CONFIG->{'acct2'}->{'myspace'};

if ( is_friend( $myspace1, $CONFIG->{'acct2'}->{'friend_id'} ) ) {

	$myspace1->delete_friend( $CONFIG->{'acct2'}->{'friend_id'} );

	if ( is_friend( $myspace1, $CONFIG->{'acct2'}->{'friend_id'} ) ) {
		fail( 'Friend deleted' );
	} else {
		pass( 'Friend deleted' );
	}

} else {
	warn "Test friend not in friend list. Skipping delete_friend test.\n";
	skip( 'Friend deleted' );
}

sub is_friend {

	my ( $myspace, $friend ) = @_;
	my @friends = $myspace->get_friends;

	my $pass=0;
	foreach my $id ( @friends ) {
		if ( $id == $friend ) {
			$pass=1;
		}
	}
	
	return $pass;

}