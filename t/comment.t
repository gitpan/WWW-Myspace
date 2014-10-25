#!perl -T

use Test::More tests => 2;
#use Test::More 'no_plan';

use lib 't';
use TestConfig;
use WWW::Myspace::Comment;

login_myspace;

my $myspace1 = $CONFIG->{'acct1'}->{'myspace'};
my $myspace2 = $CONFIG->{'acct2'}->{'myspace'};
my $comment = new WWW::Myspace::Comment( $myspace1 );

# Generate "random" seed.
my $ident = "wmyw" . int(rand(100000)) . "wmyw";

# Post a comment. We use post_all because it tests two
# methods at once.
$comment->noisy(0);
$comment->ignore_duplicates(1);
$comment->cache_file( "comexcl" );
$comment->delay_time(0);
$comment->post_all( 'Just thought I\'d comment you.\n\n- Perl\n'.${ident},
	$CONFIG->{'acct2'}->{'friend_id'} );

# Now see if we posted that comment.
my $res = $myspace1->get_profile( $CONFIG->{'acct2'}->{'friend_id'} );

if ( $res->content =~ /${ident}/ ) {
	pass( 'post_all posted comment' );
} else {
	fail( 'post_all posted comment' );
}

# Test commenting all of Perl 2's friends (checks defaults)
my $comment2 = new WWW::Myspace::Comment( $myspace2 );

$comment2->noisy(0);
$comment2->ignore_duplicates(1);
$comment2->cache_file( "comexcl" );
$comment2->delay_time(0);
$res = $comment2->post_comments( 'Just posting a test comment - thanks for helping!\n\n- Perl 2\n'.${ident} );

cmp_ok( $res, 'eq', 'DONE', 'Post Perl 2 friends' );
$comment->reset_exclusions('all');
