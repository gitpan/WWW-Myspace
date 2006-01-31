######################################################################
# WWW::Myspace.pm
# Sccsid:  %Z%  %M%  %I%  Delta: %G%
# $Id: Myspace.pm,v 1.18 2006/01/27 04:54:57 grant Exp $
######################################################################
# Copyright (c) 2005 Grant Grueninger, Commercial Systems Corp.
#
# Description:
# Module to log into myspace.com

######################################################################
# Setup

# Declare our package.
package WWW::Myspace;
use Spiffy -Base;

# *** If you're not familiar with Spiffy, read its docs. To save you
# confusion, one of its features is to add "my $self = shift;" to
# each method definition, so when you see that missing, that's why. ***

######################################################################
# Libraries we use

use Carp;
use URI::URL;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common;
use HTTP::Request::Form;
use HTML::TreeBuilder 3.0;         
use File::Spec::Functions;


=head1 NAME

WWW::Myspace - Access MySpace.com profile information from Perl

=head1 VERSION

Version 0.16

=cut

our $VERSION = '0.16';

=head1 SYNOPSIS

WWW::Myspace.pm provides methods to access your myspace.com
account and functions automatically. It provides a simple interface
for scripts to log in, access lists of friends, scan user's profiles,
retreive profile data, send messages, and post comments.

    use WWW::Myspace;
    my $myspace = WWW::Myspace->new ($account, $password);
        OR
    my $myspace = new WWW::Myspace; # Prompts for email and password
    
    my ( @friends ) = $myspace->get_friends();

This module is designed to help you automate and
centralize redundant tasks so that you can better handle keeping in
personal touch with numerous friends or fans, or coordinate fan
communications among multiple band members. This module operates well
within MySpace's security measures. If you're looking for a spambot,
this ain't it.

WWW::Myspace works by interacting with the site through a UserAgent
object, using HTTP::Request::Form to process forms. Since by nature
web sites are dynamic, if you find that some interaction with the
site breaks, check for a new version of this module (or if you
go source diving, submit a patch).


=cut

# Since WWW::Myspace reads and reacts to a web site which by nature
# may change, we define much of the basics up here where it's
# easy to see and change.

# What's the base URL for the site.
our $BASE_URL="http://www.myspace.com/";

# Where should we store files? (cookies, cache dir). We use, and untaint,
# the user's home dir for the default.
our $HOME_DIR= "";
if ( defined $ENV{'HOME'} ) {
	$HOME_DIR = "$ENV{'HOME'}";
	
	if ( $HOME_DIR =~ /^([\-A-Za-z0-9_ \/\.@\+\\:]*)$/ ) {
		$HOME_DIR = $1;
	} else {
		croak "Invalid characters in $ENV{HOME}.";
	}
}

# What's the URL for the user's Home page?
our $HOME_PAGE="http://home.myspace.com/index.cfm?fuseaction=user";

# What should we look for to see if there's a link to a friend's page?
our $FRIEND_REGEXP="fuseaction=user\.viewprofile\&friendID=";

# After posting a comment we look for text on the following page to
# tell us if the post was successful. What RE should we look for
# that we'll only see if the post was successful (this is currently
# the user's profile page, so we look for text that'll be near the top of the page).
our $VERIFY_COMMENT_POST='<span class="nametext">[^\<]*<\/span>.*View [Mm]ore [Pp]ics';

# On the page following posting a comment, what should we look for
# to indicate that the user requires comments to be approved?
# (This is only checked after VERIFY_COMMENT_POST has been checked).
our $COMMENT_APPROVAL_MSG="This user requires all comments to be approved before being posted";

our $NOT_FRIEND_ERROR="Error: You must be someone's friend to make comments about them.";

# What should we look for to see if we are being asked for a CAPTCHA code?
our $CAPTCHA='<img src="http:\/\/security.myspace.com\/CAPTCHA\/CAPTCHA\.aspx\?SecurityToken=';

# What's the URL to the comment form? We'll append the user's friend ID to
# the end of this string.
our $VIEW_COMMENT_FORM="http://www.myspace.com/index.cfm?fuseaction=user&circuitaction=viewProfile_commentForm&friendID=";

# What's the URL to view a user's profile? We'll append the friendID to the
# end of this string.
our $VIEW_PROFILE_URL="http://profile.myspace.com/index.cfm?fuseaction=user.viewprofile&friendID=";

# What's the URL to send mail to a user? We'll append the friendID to the
# end if this string too.
our $SEND_MESSAGE_FORM="http://Mail1.myspace.com/index.cfm?fuseaction=mail.message&friendID=";

# What regexp should we look for after sending a message that tells
# us the message was sent?
our $VERIFY_MESSAGE_SENT = "Your Message Has Been Sent\!";

# If a person's profile is set to "private" we'll get an error when we
# pull up the form to mail them. What regexp do we read to identify that
# page?
our $MAIL_PRIVATE_ERROR = "You can't send a message to [^<]+ because you must be [^<]+'s friend";

# If a person has set an away message, what regexp should we look for?
our $MAIL_AWAY_ERROR = "You can't send a message to [^<]+ because [^<]+ has set [^<]+ status to away";

# If we exceed our daily mail usage, what regexp would we see?
# (Note: they've misspelled usage, so the ? is in case they fix it.)
our $EXCEED_USAGE = "User has exceeded their daily use?age";

# What regexp should we use to find the "requestGUID" for a friend request?
our $FRIEND_REQUEST = "requestGUID.value='([^\']+)'";

# What's the URL to the friend requests page?
our $FRIEND_REQUEST_URL = "http://mail2.myspace.com/index.cfm?fuseaction=mail.friendRequests";

# Where do we post freind requests?
our $FRIEND_REQUEST_POST = "http://mail2.myspace.com/index.cfm?fuseaction=mail.processFriendRequests";

# Debugging? (Yes=1, No=0)
our $DEBUG=0;

######################################################################
# Methods

#---------------------------------------------------------------------
# new method
# If we're passed an account and possibly a password, we store them.
# Otherwise, we check the login cache file, and if we still
# don't have them, we ask the user.

=head1 Methods

=head2 new( $account, $password )

=head2 new( )

If called without the optional account and password, the new method
looks in a user-specific preferences file in the user's home
directory for the last-used account and password. It prompts
for the username and password with which to log in, providing
the last-used data (from the preferences file) as defaults.

Once the account and password have been retreived, the new method
automatically invokes the "site_login" method and returns a new
WWW::Myspace object reference. The new object already contains the
content of the user's "home" page, the user's friend ID, and
a UserAgent object used internally as the "browser" that is used
by all methods in the WWW::Myspace class.

    EXAMPLES
        use WWW::Myspace;
        my $myspace = new WWW::Myspace;
        
        # Print my friend ID
        print $myspace->my_friend_id;
        
        # Print the contents of the home page
        print $myspace->current_page->content;
        
        # Print all my friends with a link to their profile.
        @friend_ids = $myspace->get_friends;
        foreach $id ( @friend_ids ) {
            print 'http://profile.myspace.com/index.cfm?'.
                'fuseaction=user.viewprofile&friendID='.
                ${id}."\n";
        }

        # How many friends do we have? (Note: we don't include Tom
        # because he's everybody's friend and we don't want to be
        # bugging him with comments and such).
        print @friend_ids . " friends (not incl Tom)\n";

=cut

sub new() {
	my $proto = shift;
	my $class = ref($proto) || $proto;
 	my $self  = {};
	bless ($self, $class);
	if ( @_ ) {	$self->{account_name} = shift }
	if ( @_ ) {	$self->{password} = shift }
	unless ( $self->{account_name} ) {
		# Get account/password from the user
		$self->_get_acct();
	}
	
	# And for convenience, log in
	$self->_site_login();

	return $self;
}

#---------------------------------------------------------------------
# Value return methods
# These methods return internal data that is of use to outsiders

=head2 my_friend_id

Returns the friendID of the user you're logged in as.

EXAMPLE

	print $myspace->my_friend_id;

=cut

sub my_friend_id {
	
	return $self->{my_friend_id};
}

=head2 account_name

Returns the account name (email address) under which you're logged in.
Note that the account anem is retreived from the user or from your program
depending on how you called the "new" method.

EXAMPLE

The following would prompt the user for their login information, then print
out the account name:

	use WWW::Myspace;
	my $myspace = new WWW::Myspace;
	
	print $myspace->account_name;

=cut

sub account_name {

	return $self->{account_name};

}

=head2 user_name

Returns the profile name of the logged in account. This is the
name that shows up at the top of your profile page above your picture.
This is NOT the account name.

Normally you'll only retreive the value with this method. When logging
in, the internal login method calls this routine with the contents
of the profile page and this method extracts the user_name from the
page code. You can, if you really need to, call user_name with the
contents of a page to have it extract the user_name from it. This
may not be supported in the future, so it's not recommended.

=cut

sub user_name {

	if ( @_ ) {
		my ( $homepage ) = @_;
		my $page_source = $homepage->content;
		if ( $page_source =~ /index\.cfm\?fuseaction=user\.viewfriends\&friendID=[0-9]+\&userName=([^\&]*)/ ) {
			$self->{user_name} = $1;
		}
	}
	
	return $self->{user_name};

}

=head2 friend_count

Returns the logged in user's friend count as displayed on the
profile page ("You have NN friends").

Note that due to one of WWW::Myspace's many bugs, this count may not
be equal to the count of friends returned by get_friends.

Like the user_name method, friend_count is called by the internal
login method with the contents of the user's profile page, from
which it extracts the friend count using a regexp on the
"You have NN friends" string. If you need to, you can do so
also, but again this might not be supported in the future so do so
at your own risk.

=cut

sub friend_count {

	# If they gave us a page, set friend_count.
	if ( @_ ) {
		my ( $homepage ) = @_;
		my $page_source = $homepage->content;

		if ( $page_source =~ /You have <a [^>]+>([0-9]+)<\/a> friends/ ) {
			$self->{friend_count} = $1;
		}
	}
	
	return $self->{friend_count};

}

=head2 current_page

Returns a reference to an HTTP::Response object that contains the last page
retreived by the WWW::Myspace object. All methods (i.e. get_page, post_comment,
get_profile, etc) set this value.

EXAMPLE

The following will print the content of the user's profile page:

	use WWW::Myspace;
	my $myspace = new WWW::Myspace;
	
	print $myspace->current_page->content;

=cut

sub current_page {

	return $self->{current_page};

}

=head2 cookie_jar

Returns the path to the file we're using to store cookies. Defaults
to $ENV{'HOME'}/.cookies.txt. If called with a filename, sets
cookie_jar to that path.

If using this from a CGI script, you should set cookie_jar.

=cut

#field cookie_jar => "$HOME_DIR/.cookies.txt";
field cookie_jar => catfile( "$HOME_DIR", '.cookies.txt' );

=head2 cache_dir

WWW::Myspace stores the last account/password used in a cache file
for convenience if the user's entering it. Other modules store other
cache data as well.
cache_dir sets or returns the directory in which we should store cache
data. Defaults to $ENV{'HOME'}/.www-myspace.

If using this from a CGI script, you will need to provide the
account and password in the "new" method call, so cache_dir will
not be used.

=cut

field cache_dir => catfile( "$HOME_DIR", '.www-myspace' );

=head2 cache_file

Sets or returns the name of the file into which the login
cache data is stored. Defaults to login_cache.

If using this from a CGI script, you will need to provide the
account and password in the "new" method call, so cache_file will
not be used.

=cut

field cache_file => 'login_cache';

=head2 remove_cache

Remove the login cache file. Call this after creating the object if
you don't want the login data stored:

 my $myspace = new WWW::Myspace( qw( myaccount, mypassword ) );
 $myspace->remove_cache;

=cut

sub remove_cache {

	my $cache_file_path = catfile( $self->cache_dir, $self->cache_file );
	unlink $cache_file_path;

}

#---------------------------------------------------------------------
# _get_acct()
# Get and store the login and password. We check the user's preference
# file for defaults, then prompt them.

sub _get_acct {

	# Initialize
	my %prefs = ();
	my $ref = "";
	my ( $pref, $value, $res );
	my $cache_filepath = catfile( $self->cache_dir, $self->cache_file);

	# Read what we got last time.	
	if ( open ( PREFS, "< ", $cache_filepath ) ) {
		while (<PREFS>) {
			chomp;
			( $pref, $value ) = split( ":" );
			$prefs{"$pref"} = $value;
		}
		
		close PREFS;
	}

	# Prompt them for current values
	unless ( defined $prefs{"email"} ) { $prefs{"email"} = "" }
	print "Email [" . $prefs{"email"} . "]: ";
	$res = <STDIN>; chomp $res;
	if ( $res ) {
		$prefs{"email"} = $res;
	}

	unless ( defined $prefs{"password"} ) { $prefs{"password"} = "" }
	print "Password [". $prefs{"password"} . "]: ";
	$res = <STDIN>; chomp $res;
	if ( $res ) {
		$prefs{"password"} = $res;
	}

	# Make the cache directory if it doesn't exist.
	$self->make_cache_dir;

	# Store the new values.
	open ( PREFS, ">", $cache_filepath ) or croak $!;
	print PREFS "email:" . $prefs{"email"} . "\n" .
		"password:" . $prefs{"password"} . "\n";
	close PREFS;
	
	# Store the account info.
	$self->{account_name}=$prefs{"email"};
	$self->{password}=$prefs{"password"};
}

#---------------------------------------------------------------------
# _site_login()
# Log into myspace with the stored account login name, password, and
# URL (probably "http://www.myspace.com/")

sub _site_login {

	# Set up our web browser (User Agent)	
	my $ua = LWP::UserAgent->new;

	# We need to follow redirects for POST too.
	push @{ $ua->requests_redirectable }, 'POST';

	# Store cookies here
	$ua->cookie_jar({ file => $self->cookie_jar });

	# Set the official parameter
	$self->{ua} = $ua;
	
	# Now log in
	my $submitted = $self->submit_form( "$BASE_URL", 1, "Submit22",
						{ 'email' => $self->{account_name},
						  'password' => $self->{password}
						}
					  );

	# Check for success
	if ( $submitted ) {
		( $DEBUG ) && print $self->{current_page}->content;
	} else {
		croak $self->{current_page}->status_line;
	}
	
	# We probably have an ad or somesuch (started 1/7/2006)
	# so explicitly request our Home.
	$self->get_page( $HOME_PAGE );

	# Get our friend ID from our profile page (which happens to
	# be the page we go to after logging in).
	$self->_get_friend_id( $self->{current_page} );
	
	# Set the user_name and friend_count fields.
	$self->user_name( $self->current_page );
	$self->friend_count( $self->current_page );

}

#---------------------------------------------------------------------
# _get_friend_id( $homepage )
# This internal method stores our friend ID. We get this from the
# "View All of My Friends" link on the bottom of our profile page (the one
# we see when we first log in)

sub _get_friend_id {

	my ( $homepage ) = @_;
	
	# Search the code for the link. This is why we like Perl. :)
	my $page_source = $homepage->content;
	$page_source =~ /index\.cfm\?fuseaction=user\.viewfriends\&friendID=([0-9]+)/;
	my $friend_id=$1;
	( $DEBUG ) && print "Got friend ID: $friend_id\n";

	# Store it
	$self->{my_friend_id} = $friend_id;

}

#---------------------------------------------------------------------
# make_cache_dir

=head2 make_cache_dir

Creates the cache directory in cache_dir. Only creates the
top-level directory, croaks if it can't create it.

	$myspace->cache_dir("/path/to/dir");
	$myspace->make_cache_dir;

This function mainly exists for the internal login method to use,
and for related sub-modules that store their cache files by
default in WWW:Myspace's cache directory.

=cut

sub make_cache_dir {

	# Make the cache directory if it doesn't exist.
	unless ( -d $self->cache_dir ) {
		mkdir $self->cache_dir or croak "Can't create cache directory ".
			$self->cache_dir;
	}

}


#---------------------------------------------------------------------
# get_friends();
# Return, as an array of friend IDs, all of our friends.
# For each friend page, grep for the "view profile" links, which
# contain the friend IDs.

=head2 get_friends

Returns, as a list of friendIDs, all of your friends. It does
not include Tom, because he's everybody's friend and when you're
debugging your band central CGI page it's probably best to limit your
mistakes to actual friends.

    @friends = $myspace->get_friends;

=cut

sub get_friends {

	my $source="";
	my $source_id = "";
	( $source, $source_id ) = @_;
	
	my $friends_page="";
	my $page=0;
	my %friend_ids = ();
	my @friends_on_page = ();
	my ( $id );
	while ( 1 ) {

		# Get the page
		$friends_page = $self->_get_friend_page( $page, $source, $source_id );

		# Grep the friend IDs out
		@friends_on_page = $self->get_friends_on_page( $friends_page->content );
		last unless ( @friends_on_page );
#		warn "Got ". @friends_on_page . " friends\n";

		# Add them to the list
		# (This prevents duplicates for inbox, comments, etc)
		foreach $id ( @friends_on_page ) {
			$friend_ids{"$id"}++;
		}
		
		# Next!
		$self->{_last_friend_page} = $page;
		$page++;
	}

	# Return the list
	( $DEBUG ) && print keys %friend_ids;
	return ( sort( keys( %friend_ids ) ) );
}

#---------------------------------------------------------------------
# friends_who_emailed();
# Return a list of friends with mail in the inbox.

=head2 friends_who_emailed

Returns list of the friend IDs of all friends with messages
in your inbox (mail). Note that this only tells you who you have mail from,
not how many messages, nor does it contain any method to link to those
messages. This is primarily designed to aid in auto-responding programs
that want to not contact (comment or email) people who have sent
messages so someone can attend to them personally. This routine
also disincludes Tom, mainly because it uses the same routine
as "get_friends".

    @friends = $myspace->friends_who_emailed;

=cut

sub friends_who_emailed {

	# We just call get_friends with the code "inbox" to tell it to look
	# through those pages instead of the friends page.
	return $self->get_friends( "inbox" );
	
}

#---------------------------------------------------------------------

=head2 friends_in_group( group_id )

Returns a list of the friend IDs of all people in the
group identified by group_id. Tom is disincluded as in get_friends
(because the same routine is used to get the friendIDs).

Example:

 my @hilary_fans = $myspace->friends_in_group( 100011592 );
 
 @hilary_fans now contains the friendID of everyone in the HIlary
 Duff Fan Club group (group ID 100011592 ).
 
To get the group ID, go to the group page in WWW::Myspace and look at
the URL:
http://groups.myspace.com/index.cfm?fuseaction=groups.viewMembers&GroupID=100011592&adTopicId=&page=3
 
The group ID is the number after "GroupID=".

=cut

sub friends_in_group {

	# If they didn't give us a group, return nothing. Could
	# be argued that we should croak here.
	return () unless ( @_ );

	# Return the friends.
	return $self->get_friends( 'group', @_ );

}

#---------------------------------------------------------------------
# _get_friend_page( $page, %attr_ref )
# Examples:
# $self->_get_friend_page( 1, 'group', 100011592 );
# Gets the friends from page 1 (the second page) of the myspace
# group with ID 100011592.
#
# $self->_get_friend_page( 1 )
# Get the the friends from page 1 of the logged in user's friend pages.
#
# $self->_get_friend_page( 1, 'inbox' );
# Gets the friends from page 1 of the logged in user's mail inbox.
#
# Return the content of the friend page. $page is the page number.
# $id 

sub _get_friend_page {

	my ( $page, $source, $id ) = @_;
	
	my $url;

	# Set the URL string for the right set of pages
	if ( (defined $source ) && ( $source eq "inbox" ) ) {
		$url = "http://mail2.myspace.com/index.cfm?fuseaction=mail.inbox" .
			"&page=${page}";
	} elsif ( (defined $source ) && ( $source eq "group" ) ) { 
		$url = "http://groups.myspace.com/index.cfm?fuseaction=".
			"groups.viewMembers&GroupID=${id}&page=${page}";
	} else {
		if ( $page == 0 ) {
			# First page
			$url = "http://home.myspace.com/index.cfm?".
				"fuseaction=user.viewfriends&".
				"friendID=" . $self->my_friend_id . "&".
				"FriendCount=" . $self->friend_count . "&" .
				"userName=" . $self->user_name;
		} else {
			# Subsequent pages
			$url = "http://home.myspace.com/index.cfm?".
				"fuseaction=user.viewfriends&".
				"UserName=" . $self->user_name . "&" .
				"friendID=" . $self->my_friend_id . "&" .
				"f_search=&searchby=&" . 
				"friendCount=" . $self->friend_count . "&" .
				"page=" . $page . "&" .
				"lastpage=" . $self->{_last_friend_page} . "&" .
				"PREVPageLASTONERETURENED=" . $self->{_high_friend_id} . "&" .
				"PREVPageFirstONERETURENED=" . $self->{_low_friend_id}."&".
#				"lastpageofset=" . $self->{_total_friend_pages} . "&".
				"TotalRecords=" . $self->friend_count;
		}

#			warn "processing page $url\n";
	}

	# Get the page	
	my $res = $self->get_page( $url );

	return $res;
}

#---------------------------------------------------------------------

=head2 get_page( $url )

get_page returns a referece to a HTTP::Response object that contains
the web page specified by $url.

Use this method if you need to get a page that's not available
via some other method. You could include the URL to a picture
page for example then search that page for friendIDs using
get_friends_on_page.

get_page will try up to 20 times until it gets the page, with a 5-second
delay between attempts.
This is designed to get past network problems and such.

EXAMPLE

    The following displays the HTML source of MySpace.com's home
    page.
    my $res=get_page( "http://www.myspace.com/" );
    
    print $res->content;

=cut

sub get_page {

	my ( $url ) = @_;

	# Get our web browser object
	my $ua = $self->{ua}; # For readability...

	# Try to get the page
	my $res = $ua->get("$url");
	
	# Check for actual errors and try again
	my $attempts=0;
	unless ( ( $res->is_success ) || ( $attempts > 20 ) ) {
		warn "Error getting page: $url\n" .
			"  " . $res->status_line . "\n";
		sleep 5;
		$res = $ua->get("$url");
	}

	# We both set "current_page" and return the value.
	$self->{current_page}=$res;
	return ( $res );

}

#---------------------------------------------------------------------
# get_friends_on_page( $page );
# This routine takes the SOURCE CODE of the page and returns
# a list of friendIDs for which there are profile links on the page.
# Notes:
# - Our friend ID will be one of those returned, so we check for it.
# - We use the hash method because there are multiple links for each user
#   (hence duplicate friendIDs will be returned). (One link for the name,
#   one for their image). This is pretty safe against changes to the page.
# - We filter out 6229, Tom's ID...

=head2 get_friends_on_page( $friends_page );

This routine takes the SOURCE CODE of an HTML page and returns
a list of friendIDs for which there are profile
links on the page. This routine is used internally by "get_friends"
to scan each of the user's "View my friends" pages.

Notes:
 - It does not return our friendID.
 - friendIDs are filtered so they are unique (i.e. no duplicates).
 - We filter out 6229, Tom's ID.

EXAMPLE:

List the friendIDs mentioned on Tom's profile:
    
    use WWW::Myspace;
    my $myspace = new WWW::Myspace;

    $res = $myspace->get_profile( 6229 );
    
    @friends = $myspace->get_friends_on_page( $res->content );
    print "These people have left comments or have links on Tom's page:\n";
    foreach $id ( @friends ) {
        print "$id\n";
    }

=cut

sub get_friends_on_page {

	my ( $page ) = @_;

	my %friend_ids = ();
	my $line;
	my @lines = split( "\n", $page );
	$self->{_high_friend_id} = 0;
	$self->{_low_friend_id} = 0;
	foreach $line ( @lines ) {
		if ( $line =~ /${FRIEND_REGEXP}([0-9]+)/i ) {
			unless ( ( "$1" == $self->{my_friend_id} ) || ( "$1" == 6221 ) ) {
				$friend_ids{"$1"}++;
				
				# The following are used to construct the URL
				# when crawling the user's "view all my friends" pages.
				# Set high friendID on this page
				if ( $self->{_high_friend_id} < $1 ) {
					$self->{_high_friend_id} = $1;
				}
				# Set low friendID on this page
				if ( ( $self->{_low_friend_id} == 0 ) ||
					 ( $1 < $self->{_low_friend_id} ) ) {
					$self->{_low_friend_id} = $1;
				}
			}
		}
	}

	return ( keys( %friend_ids ) );
}

#---------------------------------------------------------------------
# get_profile( $friend_id )
# Return the friend's profile page as an HTTP::Response object

=head2 get_profile( $friend_id )

Returns a reference to a HTTP::Response object that contains the
profile page for $friend_id.

    The following displays the HTML source code of the friend's
    profile identified by "$friend_id":

    my $res = $myspace->get_profile( $friend_id );

    print $res->content;

=cut

sub get_profile {

	my ( $friend_id ) = @_;

	return $self->get_page( "${VIEW_PROFILE_URL}${friend_id}" );

}

#---------------------------------------------------------------------
# post_comment( $friend_id, $message )
# Post $message as a comment to $friend_id's profile
# Return a status code:
# P = Posted
# PA = Posted, requires approval
# F = Failed

=head2 post_comment( $friend_id, $message )

Post $message as a comment for the friend identified by $friend_id.
The routine confirms success or failure by reading the resulting
page. It returns a status string as follows:

 P: Posted. This means the post went through and we read the
 			phrase we needed from the resulting page.
 PA: Posted, requires approval
 FN: Failed Network. The POST returned a bad status.
 FC: Failed. A CAPTCHA response was requested.
 FF: Failed. Got "You must be someone's friend to post a comment" error.
 F: Failed. The post went through, but we didn't get the phrase
 			we needed to verify that it was ok.

Warning: It is possible for the status code to return a false
"Failed" if the form post is successful but the resulting page fails
to load.

EXAMPLE:
    use WWW::Myspace;
    my $myspace = new WWW::Myspace;

    foreach $id ( $myspace->friends_who_emailed ) {
        $status = $myspace->post_comment( $id, "Thanks for the message!" )
    }

=cut

sub post_comment {

	my ( $friend_id, $message ) = @_;
	my $status = ""; # Our return status
	my ($submitted, $attempts);

#	my ( $dbh, $ua, $login, $message, $friend_id ) = @_;

#	my $approval_req = 0;
#	
#	# Get their name if we know it
#	my $friend_name = $self->get_friend_name( $friend_id );
#
#	# Add a greeting if we know their name
#	# (NOTE: This should be a search&replace in a seperate $message)
#	if ( $friend_name ) {
#		$message = "Hi $friend_name!\n\n" . $message;
#	}
	
	# HTML-ize the message like myspace's javascript does.
	# This also takes care of possible literal "\n"s that come
	# from commend-line arguments.
	$message =~ s/(\n|\\n)/<br>\n/gs;

	# Submit the comment to $friend_id's page
	( $DEBUG ) && print "Getting comment form..\n";
	$submitted = 
		$self->submit_form( "${VIEW_COMMENT_FORM}${friend_id}", 1,
						"", { 'f_comments' => "$message" }
					);
	
	# If we posted ok, confirm the comment
	if ( $submitted ) {
	
		# See if there's a CAPTCHA response required, if so,
		# fail appropriately.
		if ( $self->{current_page}->content =~ /$CAPTCHA/ ) {
			return "FC";
		}
		
		# Check for the "not your friend" error
		if ( $self->{current_page}->content =~ /$NOT_FRIEND_ERROR/ ) {
			return "FF";
		}

		# Otherwise, confirm it.
		( $DEBUG ) && print "Confirming comment...\n";
		$submitted = $self->submit_form( $self->{current_page}, 1, "",
				{} );
	}

	# Get the resulting page and clean it up (strip whitespace)
	my $page = $self->{current_page}->content;
	$page =~ s/[ \t\n\r]+/ /g;

	# Set the status code to return.
	if (! $submitted ) {
		$status="FN";
	} elsif ( $page =~ /$VERIFY_COMMENT_POST/ ) {
		$status="P";
	} elsif ( $page =~ /$COMMENT_APPROVAL_MSG/ ) {
		$status = "PA";
	} else {
		$status="F";
	}

	return "$status";
}

#---------------------------------------------------------------------
# comment_friends( $message, $attr )
# Posts a comment to all of our friends. $attr is a hash reference
# containing selection criteria.
# Example:
# $myspace->comment_friends( "Merry Christmas!", { 'ignore_dup' => 'Y' } );
# (Note: we don't handle the filtering here yet)

=head2 comment_friends( $message )

=head2 comment_friends( $message, { 'ignore_dup' => 1 } )

This convenience method sends the message in $message to
all of your friends. (Since you can only comment friends, it
sends the comment to everyone you can).

If called in the second form, it uses the "already_commented" method
to determine if a comment has already been left on each friend's page
and skips the page if it detects a previous comment.

Note that you'll probably want to use the WWW::Myspace::Comment module
as if the process is interrupted (which is likely), this
routine doesn't offer a way to recover. 
The WWW::Myspace::Comment module logs where comments have been left, scans for
previous comments we've left on the user's page, and can stop after a
specified number of posts to avoid triggering security measures. It can also
be re-run without leaving duplicate comments.

Of course, if you just want to whip off a quick comment to a few (less than
50) friends, this method's for you.

EXAMPLE:
    A simple script to leave a comment saying "Merry Christmas"
    to everyone on your friends list:

    use WWW::Myspace;
    my $myspace = new WWW::Myspace;
    $myspace->comment_friends( "Merry Christmas!" );

=cut

sub comment_friends {

	my ( $message, $attr ) = @_;

	my $status = "";
	my $friend_id;
	
	# Get friends
	my @friends=$self->get_friends;
	
	# Loop and post
	foreach $friend_id ( @friends ) {
		# If we can ignore duplicates or we haven't commented them already,
		# post the comment.
		if ( ( $$attr{'ignore_dup'} ) ||
			(! $self->already_commented( $friend_id ) ) )  {
			
			$status = $self->post_comment( $friend_id, $message );
		}
	}

}

#---------------------------------------------------------------------
# already_commented( $friend_id );
# Return true if we've previously left a comment for this person.

=head2 already_commented

Returns true if there is a link to our profile on "$friend_id"'s page.
(If we've left a comment, there'll be a link).

Note that if you're friends with this person and they have another link
to your profile on their page, this will return true, even though
you may not have left a comment.

EXAMPLE

  my WWW::Myspace;
  my $myspace = new WWW::Myspace;
  
  foreach $friend_id ( $myspace->get_friends ) {
	  unless ( $myspace->already_commented( $friend_id ) {
	  	$myspace->post_comment(
	  		$friend_id,
	  		"Hi, I haven't commented you before!"
	  	)
	  }
  }

=cut

sub already_commented {

	my ( $friend_id ) = @_;

	# Get the page
	my $page = $self->get_profile( $friend_id )->content;
	
	# Set up our regular expression. We're looking for the link code
	my $regexp = $FRIEND_REGEXP . $self->my_friend_id;

	# If the link's on their page, return true, otherwise return false.	
	if ( $page =~ /${regexp}/i ) {
		return 1
	} else {
		return 0;
	}

}

#---------------------------------------------------------------------

=head2 send_message( $friend_id, $subject, $message )

Send a message to the user identified by $friend_id.

Returns a status code:

 P: Posted. Verified by HTTP response code and reading a regexp
 	from the resulting page saying the message was sent.
 FC: Failed. A CAPTCHA response was requested.
 FF: Failed. The person's profile is set to private. You must
     be their friend to message them.
 FA: Failed. The person has set their status to "away".
 FE: Failed. The account has exceeded its daily usage.
 FN: Failed. The POST returned an unsuccessful HTTP response code.
 F:  Failed. Post went through, but we didn't see the regexp on the
 	resulting page (message may or may not have been sent).

=cut

sub send_message {

	my ( $friend_id, $subject, $message ) = @_;
	my ( $submitted, $res, $page );

	# Try to get the message form
	$res = $self->get_page( "${SEND_MESSAGE_FORM}${friend_id}" );
	
	# See if we can mail or if there's an error.
	if ( $res->is_success ) {
		$page = $res->content;
		$page =~ s/[ \t\n\r]+/ /g;
		if ( $page =~ /${MAIL_PRIVATE_ERROR}/i ) {
			return "FF";
		} elsif ( $page =~ /${MAIL_AWAY_ERROR}/i ) {
			return "FA";
		}
	} else {
		return "FN";
	}

	# Takes care of possible literal "\n"s that come
	# from commend-line arguments.
	$message =~ s/\\n/\n/gs;

	# Submit the message
	$submitted = $self->submit_form( $res,
						1, "",
						{ 'subject' => "$subject",
						  'mailbody' => "$message"
						}
					  );
	
	$page = $self->{current_page}->content;
	$page =~ s/[ \t\n\r]+/ /g;

	# Return the result
	if (! $submitted ) {
		return "FN";
	} elsif ( $page =~ /$VERIFY_MESSAGE_SENT/ ) {
		return "P";
	} elsif ( $page =~ /${EXCEED_USAGE}/i ) {
		return "FE";
	} elsif ( $page =~ /$CAPTCHA/ ) {
		return "FC";
	} else {
		return "F";
	}
}

#---------------------------------------------------------------------

=head2 approve_friend_requests( [message] )

Looks for any new friend requests and approves them.
Returns a list of friendIDs that were approved.
If "message" is given, it will be posted as a comment to the
new friend.

EXAMPLE

  # Approve any friend requests
  @friends_added = $myspace->approve_friend_requests;

  # Print the number of friends added and their friend IDs.
  print "Added " . @friends_added . " friends: @friends_added.";

  # Approve new frieds and leave them a thank you comment.
  @friends_added = $myspace->approve_friend_requests(
    "Thanks for adding me!\n\n- Your nww friend" );

Run it as a cron job. :)

Note that "\n" is properly handled if you pass it literally also (i.e.
from the command line). That is if you write this "approve_friends"
script:

 #!/usr/bin/perl -w
 # usage: approve_friends [ "message" ]
 
 use WWW::Myspace;
 my $myspace = new WWW::Myspace;
 
 $myspace->approve_friend_requests( @ARGV );
 
 And run it as:
 
 approve_friends "Thanks for adding me\!\!\n\n- Me"
 
You'll get newlines and not "\n" in the message. There, I even gave
you your script.

=cut

sub approve_friend_requests
{

	my @guids = ();
	my @friends = ();
	my %friends = ();  # Not a typo. See below.
	my ( $page, $id );
	my ( $message ) = @_;

	# Get the first page of friend requests
	while ( 1 ) {
		
		# Get the page
		$page = $self->get_page( $FRIEND_REQUEST_URL )->content;

		# Get the GUID codes from the page
		@guids = $self->_get_friend_requests( $page );
		
		# Quit if there aren't any.
		last unless ( @guids );

		# Get the friendIDs from the page
		@friends = ( @friends, $self->get_friends_on_page( $page ) );

		# Post approval for any we found
		$self->_post_friend_requests( @guids );

	}

	# Clean up friends (there -could- be duplicates in some circomstances)
	foreach $id ( @friends ) {
		$friends{"$id"}++;
		( $message ) && $self->post_comment( $id, $message );
	}
	
	# Return the list of friends
	return keys( %friends );

}

#---------------------------------------------------------------------
# _get_friend_requests()
# Returns a list of friend requests from the Friend Requests page

sub _get_friend_requests
{
	my ( $page ) = @_;

	my %guids = ();
	my $line = "";

	# Get the GUID codes from it.	
	while ( $page =~ s/$FRIEND_REQUEST//im ) {
		$guids{"$1"}++;
	}
	
	return keys( %guids );
}

#---------------------------------------------------------------------
# _post_friend_requests( @guids )
# Post each GUID (friend request code)

sub _post_friend_requests
{
	my ( @guids ) = @_;
	my ( $submitted, $guid, $res, $pass );

	# For each request post the approval form.
	$pass=1;
	foreach $guid ( @guids ) {

#		print "Approving guid: " . $guid . "\n";
		
		# Post it.
		$res=$self->{ua}->post( $FRIEND_REQUEST_POST,
					{ requestType => 'SINGLE',
					  requestGUID => $guid,
					  actionType  => 0,
					  approve => ' Approve '
					} );

		unless ( $res->is_success ) {
			$pass=0;
#			print $res->status_line . "\n";
		}
	}

	return $pass;

}

#---------------------------------------------------------------------
# send_friend_request

=head2 send_friend_request( @friend_ids )

Send a friend request to each friend in the list of @friend_ids.

This is the same as going to their profile page and clicking
the "add as friend" button and confirming that you want to add them.

 $myspace->send_friend_request( 12345, 123456 );

Returns 1 if all requests were submitted ok, 0 if any failed.

=cut

sub send_friend_request {

	# We pass unless 
	my $pass = 1;

	foreach my $id ( @_ ) {
		my $res = $self->submit_form(
			'http://www.myspace.com/index.cfm?'.
			'fuseaction=invite.addfriend_verify&'.
			'friendID=' . $id, 1, '', {} );
		unless ( $res ) { $pass = 0 }
	}
	
	return ( $pass );
}

=head2 add_as_friend

Convenience method - same as send_friend_request. This method's here
because the button on Myspace's site that the method emulates
is usually labeled "Add as friend".

=cut

sub add_as_friend {
	$self->send_friend_request( @_ );
}

#---------------------------------------------------------------------
# delete_friend

=head2 delete_friend( @friend_ids )

Deletes the list of friend_ids passed from your list of friends.

 $myspace->delete_friend( 12345, 151133 );

Returns true if it posted ok, false if it didn't.

(This method is a bit inefficient if deleting more than one friend
due to a documented bug in HTTP::Request::Form. It should probably
be moved to WWW::Mechanize.)

=cut

sub delete_friend {

	my ( $form, $tree, $f, $res, $id );
	my $pass=1;

	foreach $id ( @_ ) {
		# Create the form
		$form =
			'<FORM ACTION="index.cfm?fuseaction=user.deleteFriend" '.
			'METHOD="POST">';

		$form .= '<input type="checkbox" name="delFriendID" value="'
			. $id . '">';

		$form .= '<input type="image" border="0" name="deleteAll" '.
			'src="images/btn_deleteselected.gif" width="129" height="20">'.
			'</form>';

		# Turn it into an HTML::Elements tree
		$tree = HTML::TreeBuilder->new_from_content( $form );
		$tree = $tree->elementify;

#		$tree->dump;
		
		# Parse that into a HTTP::Request::Form object
		my @forms = HTTP::Request::Form->new_many(
			$tree, 'http://www.myspace.com/' );
		$f = $forms[0];

		# Check the checkboxes
#		warn "Setting checkbox\n";
		$f->checkbox_check( 'delFriendID' );

#		if ( $f->checkbox_ischecked( 'delFriendID' ) ) {
#			warn "Checkbox checked\n";
#		}

		# Submit the form
#		$f->dump;

		$res = $self->{'ua'}->request( $f->press( 'deleteAll' ) );	

		unless ( $res->is_success ) {
			$pass=0;
		}
	}

	return $pass;

}

#---------------------------------------------------------------------
# get_friend_name( $friend_id )
# Return the first name of $friend_id, if we have it.

#sub get_friend_name {
#
#	my $self = shift;
#	
#	my ( $friend_id ) = @_;
#
#	# Just select and return :)
#	my $first_mame = $self->{dbh}->selectrow_arrayref("select first_name from friends where friendid=${friend_id}");
#	
#	return $first_name;
#
#}

#---------------------------------------------------------------------
# submit_form( $url, $form_no, $button, $fields_ref )
# Fill in and submit a form on the specified web page.
# $url is the URL of the page OR a reference to a HTTP::Request object.
# $form_no is the number of the form (starting at 0). i.e. if there
# are 2 forms on the page and you want to submit to the 2nd one, set
# $form_no to "1").
# $button is the name of the button of the form to press.
# $fields_ref is a reference to a hash that contains field names
# and values you want to fill in on the form.
# submit_form returns 1 if it succeeded, 0 if it fails.

=head2 submit_form( $url, $form_no, $button, $fields_ref )

This powerful little method reads the web page specified by $url,
finds the form specified by $form_no, fills in the values
specified in $fields_ref, and clicks the button named "$button".

You may or may not need this method - it's used internally by
any method that needs to fill in and post a form. I made it
public just in case you need to fill in and post a form that's not
handled by another method (in which case, see CONTRIBUTING below :).

$url can either be a text string to a URL, or a reference to an
HTTP::Response object that contains the source of the page
that contains the form.

$form_no is used to numerically identify the form on the page. It's a
simple counter starting from 0.  If there are 3 forms on the page and
you want to fill in and submit the second form, set $form_no to "1".
For the first form, use "0".

$button is the name or type of button to submit. This will frequently
be "submit", but if they've named the button something clever like
"Submit22" (as MySpace does in their login form), then you may have to
use that.

$fields_ref is a reference to a hash that contains field names
and values you want to fill in on the form.

EXAMPLE

This is how post_comment actually posts the comment:

	# Submit the comment to $friend_id's page
	$self->submit_form( "${VIEW_COMMENT_FORM}${friend_id}", 1, "submit",
						{ 'f_comments' => "$message" }
					);
	
	# Confirm it
	$self->submit_form( $self->{current_page}, 1, "submit", {} );

The comment form is a 2-step process. The first command gets the form
and fills it in, then posts it. WWW::Myspace then returns the HTML display
of the form with a "Post Comment" button. So we just need to click that
button ("Post Comment" is the button's "value", but its type is "submit".
You could probably use either value. See the "press" method in
"perldoc HTTP::Request::Form" for more info).
We send that confirmation page to submit_form as a reference to the
page returned by the first post.

=cut

sub submit_form {

	my ( $url, $form_no, $button, $fields_ref ) = @_;

	# Initialize our variables
	my $ua = $self->{ua}; # For convenience
	my $res = "";
	my ( $field );
	
	# Get the page
	( $DEBUG ) && print "Getting $url...\n";
	if ( ref( $url ) ) {
		# They gave us a page already
		$res = $url;
	} else {
		$res = $self->get_page( $url );
	}

	# Parse the page
	my $tree = HTML::TreeBuilder->new_from_content($res->content);
	$tree = $tree->elementify();

	# Work around a bug in HTML::Request::Form
	&_fix_textareas( $tree );

	# Find the forms, fail if there aren't any
#	( $DEBUG ) && print "\n\nExtracting forms from the following:\n";
#	( $DEBUG ) && $tree->dump;

	my @forms = HTTP::Request::Form->new_many( $tree, $BASE_URL );
	$tree = $tree->delete();
	return 0 unless @forms;
	
	# Get the one we want by number (this could be fancier)
	return 0 unless $forms[$form_no];

	my $f = $forms[$form_no];
	if ( $DEBUG ) {
		print "I think this is the requested form:\n";
		$f->dump();
	
		print "Posting URL:\n" . $f->link . "\n";
		print "Posting method:\n" . $f->method . "\n\n";
		
	}

	# Fill in the fields
	foreach $field ( keys( %$fields_ref ) ) {
		( $DEBUG ) && print "Filled in $field with " .
					$$fields_ref{"$field"} . "\n";
#		warn "Filling in field " . $field . "\n";
		$f->field( "$field", "$$fields_ref{\"$field\"}" );
	}
	if ($DEBUG) {
		print "Dump of form filled in:\n";
		$f->dump();
		print "\n\n";
		
		if ( $f->field("f_comments") ) {
			print "Comment entered: " . $f->field("f_comments")."\n"
		}
	}

	# Press the submit button.
	my $attempts = 0;
	do
	{
		if ( $button ) {
			$res = $ua->request($f->press("$button"))
		} else {
#			warn "pressing button\n";
			$res = $ua->request($f->press())
		}
		
		$attempts++;
		
		sleep 2 unless ( $res->is_success );

	} until ( ( $res->is_success ) || ( $attempts > 5 ) );
	
	# Return the result
	$self->{current_page} = $res;
	return $res->is_success;

}

#---------------------------------------------------------------------
# _fix_textareas( $tree )
# Takes an HTML::Element node and traverses it, fixing any
# textarea elements so they have a content element.
# Bug workaround - HTTP::Request::Form will die if a textarea
# field has no content (because the parser doesn't add a
# "_content" element). So, we add one.

sub _fix_textareas() {

	my $x = $_[0];
	# If this is a textarea, push an empty string as the
	# content if it doesn't have any.
	if ( $x->tag eq "textarea" ) {
		$x->{_content} = [] unless defined $x->content;
	}

	# Recursively traverse the tree on our search.
	foreach my $c ($x->content_list) {
		_fix_textareas($c) if ref $c; # ignore text nodes
	}
}

1;

__END__



=head1 AUTHOR

Grant Grueninger, C<< <grantg at cpan.org> >>

=head1 KNOWN ISSUES

=over 4

=item -

post_comment dies if it is told to post to a friendID that
is not a friend of the logged-in user. (MySpace displays
an error instead of a form).

=back

=head1 TODO

Add an option to include the "add to friends" button after a message
automatically.

  Hint:
  <a href="http://www.myspace.com/index.cfm?fuseaction=invite.addfriend_verify&friendID=37033247"><img src="http://i.myspace.com/site/images/addFriendIcon.gif" alt="Add as friend"></a>
  (Replace "37033247" with your friend ID)

Have 'add_to_friends' method check GUIDS after first submit to make
sure the current page of GUIDS doesn't contain any duplicates. This
is to prevent a possible infinite loop that could occur if the
submission of the friend requests fails, and also to signal a warning
if myspace changes in a way that breaks the method.

Add checks to all methods to self-diagnose to detect changes in myspace
site that break this module.

=head1 CONTRIBUTING

If you would like to contribute to this module, you can email me
and/or post patches at the RT bug links below. There are many methods that
could be added to this module (profile editing, for example). If you
find yourself using the "submit_form" method, it probably means you
should write whatever you're editing into a method and post it on RT.

See the TODO section above for starters.

=head1 BUGS

Please report any bugs or feature requests, or send any patches, to
C<bug-www-myspace at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Myspace>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

Bug reports are nice, patches are nicer.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Myspace

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Myspace>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Myspace>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Myspace>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Myspace>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Grant Grueninger, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
