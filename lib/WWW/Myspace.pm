######################################################################
# WWW::Myspace.pm
# Sccsid:  %Z%  %M%  %I%  Delta: %G%
# $Id: Myspace.pm,v 1.68 2006/03/16 17:11:55 grant Exp $
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
use Contextual::Return;
use WWW::Mechanize;
use File::Spec::Functions;

=head1 NAME

WWW::Myspace - Access MySpace.com profile information from Perl

=head1 VERSION

Version 0.36

=cut

our $VERSION = '0.36';

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
go source diving, submit a patch). You can run "cpan -i WWW::Myspace"
as a cron job or before running your scripts, if appropriate, to
make sure you have the latest version.

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

# What regexp should we look for to verify that we're logged in?
# This is checked against the home page when we log in.
our $VERIFY_HOME_PAGE = 'Hello,.*My Mail.*You have .* friends';

# What's the URL to the Browse page?
our $BROWSE_PAGE = 'http://browseusers.myspace.com/browse/Browse.aspx';

# What should we look for to see if there's a link to a friend's page?
our $FRIEND_REGEXP="fuseaction=user\.viewprofile\&friendID=";

# After posting a comment we look for text on the following page to
# tell us if the post was successful. What RE should we look for
# that we'll only see if the post was successful (this is currently
# the user's profile page, so we look for text that'll be near the top of the page).
our $VERIFY_COMMENT_POST='<span class="nametext">[^\<]*<\/span>.*View [Mm]ore [Pp]ics';

# After loading a person's profile page, we look for this RE to
# verify that we actually got the page.
# It just so happens that when we post a comment, it takes us back to
# their profile, so these are the same.
our $VERIFY_GET_PROFILE='<span class="nametext">[^\<]*<\/span>';

# On the page following posting a comment, what should we look for
# to indicate that the user requires comments to be approved?
# (This is only checked after VERIFY_COMMENT_POST has been checked).
our $COMMENT_APPROVAL_MSG="This user requires all comments to be approved before being posted";

our $NOT_FRIEND_ERROR="Error: You must be someone's friend to make comments about them.";

# What should we look for to see if we are being asked for a CAPTCHA code?
# We'll extract the URL to return from the area in parenthesis.
our $CAPTCHA='<img src="(http:\/\/security.myspace.com\/CAPTCHA\/CAPTCHA\.aspx\?SecurityToken=[^"]+)"';

# What's the URL to the comment form? We'll append the user's friend ID to
# the end of this string.
our $VIEW_COMMENT_FORM="http://comments.myspace.com/index.cfm?fuseaction=user&circuitaction=viewProfile_commentForm&friendID=";

# What's the URL to view a user's profile? We'll append the friendID to the
# end of this string.
our $VIEW_PROFILE_URL="http://profile.myspace.com/index.cfm?fuseaction=user.viewprofile&friendID=";

# Mail Inbox URL
# What's the URL to read a page from our inbox?
our $MAIL_INBOX_URL="http://mail.myspace.com/index.cfm?fuseaction=mail.inbox" .
			"&page=";

# What's the URL to read a message if we know the messageID?
our $READ_MESSAGE_URL='http://mail.myspace.com/index.cfm?fuseaction=mail.readmessage&messageID=';
# What's the URL to send mail to a user? We'll append the friendID to the
# end if this string too.
our $SEND_MESSAGE_FORM="http://mail.myspace.com/index.cfm?fuseaction=mail.message&friendID=";

# What regexp should we look for after sending a message that tells
# us the message was sent?
our $VERIFY_MESSAGE_SENT = "Your Message Has Been Sent\!";

# If a person's profile is set to "private" we'll get an error when we
# pull up the form to mail them. What regexp do we read to identify that
# page?
our $MAIL_PRIVATE_ERROR = "You can't send a message to [^<]+ because you must be [^<]+'s friend";

# If a person has set an away message, what regexp should we look for?
our $MAIL_AWAY_ERROR = "You can't send a message to [^<]+ because [^<]+ has set [^<]+ status to away";

# What regexp should we look for for Myspace's frequent "technical error"
# message?
# This lists regexps to look for on pages that indicate we've got an error
# instead of a successful load or post. Note: Page content is stripped
# of extra whitespace before checking, so make sure any spaces you have here
# are single spaces, not multiple, nor tabs, nor returns.
our @ERROR_REGEXPS = (

	"Sorry! an unexpected error has occurred\. <br><br> ".
		"This error has been forwarded to MySpace's technical group\.",

	'<b>This user\'s profile has been temporarily '.
	'disabled for special maintenance.<br>'.
	
	'This profile is undergoing routine maintenance. '.
	'We apologize for the inconvenience!',
	
	'An Error has occurred!!.*'.
	'An error has occurred (while )?trying to send this message.',

);

# If we exceed our daily mail usage, what regexp would we see?
# (Note: they've misspelled usage, so the ? is in case they fix it.)
our $EXCEED_USAGE = "User has exceeded their daily use?age";

# What regexp should we use to find the "requestGUID" for a friend request?
our $FRIEND_REQUEST = "requestGUID.value='([^\']+)'";

# What's the URL to the friend requests page?
our $FRIEND_REQUEST_URL = "http://mail.myspace.com/index.cfm?fuseaction=mail.friendRequests";

# Where do we post freind requests?
our $FRIEND_REQUEST_POST = "http://mail.myspace.com/index.cfm?fuseaction=mail.processFriendRequests";

# What's the URL for a friend request button (to send a friend request)?
our $ADD_FRIEND_URL = 'http://collect.myspace.com/index.cfm?'.
			'fuseaction=invite.addfriend_verify&'.
			'friendID=';

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
	my $mech = new WWW::Mechanize( onerror => undef );

	# We need to follow redirects for POST too.
	push @{ $mech->requests_redirectable }, 'POST';
	
	# Set the official parameter
	$self->{mech} = $mech;
	
	# Now log in
	my $submitted = $self->submit_form( "$BASE_URL", 1, "",
						{ 'email' => $self->{account_name},
						  'password' => $self->{password}
						}
					  );

	# Check for success
	if ( $submitted ) {
		( $DEBUG ) && print $self->current_page->content;
	} else {
		croak $self->current_page->status_line;
	}
	
	# We probably have an ad or somesuch (started 1/7/2006)
	# so explicitly request our Home.
	$self->get_page( $HOME_PAGE );
	
	# Verify we're logged in
	if ( $self->current_page->content =~ /$VERIFY_HOME_PAGE/si ) {
		$self->logged_in( 1 );
	} else {
		$self->logged_in( 0 );
		return;
	}

	# Get our friend ID from our profile page (which happens to
	# be the page we go to after logging in).
	$self->_get_friend_id( $self->current_page );

	# If for some reason we couldn't set this, fail login.
	unless ( $self->my_friend_id ) { $self->logged_in(0) ; return }
	
	# Set the user_name and friend_count fields.
	$self->user_name( $self->current_page );
	$self->friend_count( $self->current_page );
	
	# Cache whether or not we're a band.
	$self->is_band;

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
	
	if ( $friend_id ) {
		$self->error(0)
	} else {
		$self->error("Couldn't get friendID from home page")
	}

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
Note that the account name is retreived from the user or from your program
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

=head2 is_band( [friend_id] )

Returns true if friend_id is a band profile.  If friend_id isn't passed,
returns true if the account you're logged in under is a band account.
If it can't get the profile page it returns -1 and you can check
$myspace->error for the reason (returns a printable message).
This is used by send_friend_request to not send friend requests to
people who don't accept them from bands, as myspace passively accepts
the friend request without displaying an error, but doesn't add the friend
request.

 EXAMPLE
 
 $myspace->is_band( $friend_id );

 if ( $myspace->error ) {
 	 die $myspace->error . "\n";
 } else {
 	 print "They're a band, go listen to them!\n";
 }

=cut

sub is_band {
	my ( $friend_id ) = @_;
	
	# If they gave a friend_id, we load the profile and look at it.
	# If not, we return, or set, our internal is_band variable.
	if ( defined $friend_id ) {
		# Get the profile page
		my $res = $self->get_profile( $friend_id );
		unless ( $self->error ) {
			# Scan the page for band-specific RE (the music player plug-in).
			if ( $res->content =~ /<PARAM NAME="Movie" VALUE="http:\/\/lads.myspace.com\/music\/musicplayer.swf/i ) {
				return 1;
			} else {
				return 0;
			}
		} else {
			return -1;
		}
	} else {
		# Band profiles don't have bulletin spaces (yet). I don't
		# like counting on this, but I can't really think of anything
		# better to look for right now.
		# Note that this requires is_band to be called for the first time
		# just after loading the login profile page. _site_login calls
		# this method to take care of that problem.
		unless ( defined $self->{is_band} ) {
			if ( $self->current_page->content =~ />My Bulletin Space</i ) {
				$self->{is_band} = 0;
			} else {
				$self->{is_band} = 1;
			}
		}

		return $self->{is_band};
		
	}

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
		if ( $page_source =~ /<h4 +class="heading">Hello, (.*)\!<\/h4>/ ) {
#			my $line = $1;
#			$line =~ s/\+/ /g;
#			$line =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
			$self->{user_name} = $1;
		}
	}
	
	return $self->{user_name};

}

=head2 friend_user_name( friend_id )

Returns the profile name of the friend specified by friend_id.
This is the name that shows up at the top of their profile page
above their picture. (Note, DON'T go using this to sign comments
because most users use funky names and it'll just look cheesy.
If you really want to personalize things, write a table mapping
friend IDs to first names - you'll have to enter them yourself).

=cut

sub friend_user_name {

	my $page = $self->get_profile( @_ );

	if ( $page->content =~ /index\.cfm\?fuseaction=user\&circuitaction\=viewProfile_commentForm\&friendID\=[0-9]+\&name\=([^\&]+)\&/ ) {
		my $line = $1;
		$line =~ s/\+/ /g;
		$line =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
		return $line;
	} else {
		return "";
	}
}

=head2 friend_url( friend_id )

Returns the custom URL of friend_id's profile page. If they haven't
specified one, it returns an empty string.

 Example:
 
 foreach my $friend_id ( $myspace->get_friends ) {
     my $url = $myspace->friend_url( $friend_id );
     if ( $url ) {
	     print 'Friend's custom URL: http://www.myspace.com/' .
	     $myspace->friend_url( $friend_id );
     } else {
         print 'Friend doesn't have a custom URL. Use: '.
         'http://www.myspace.com/' . $friend_id;
     }
 }

=cut

sub friend_url {

	my $page = $self->get_profile( @_ );

	if ( $page->content =~ /\<title\>[\s]*www.myspace\.com\/([\S]*)[\s]*\<\/title\>/ ) {
		return $1;
	} else {
		return "";
	}
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

		if ( $page_source =~ /You have (<span>)?<a [^>]+>([0-9]+)<\/a>(<\/span>)? friends/ ) {
			$self->{friend_count} = $2;
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

=head2 logged_in

Returns true if login was successful. When you call the new method
of WWW::Myspace, the class logs in using the username and password you
provided (or that it prompted for).  It then retreives your "home"
page (the one you see when you click the "Home" button on myspace.com,
and checks it against an RE.  If the page matches the RE, logged_in is
set to a true value. Otherwise it's set to a false value.

 Notes:
 - This method is only set on login. If you're logged out somehow,
   this method won't tell you that (yet - I may add that later).
 - The internal login method calls this method to set the value.
   You can (currently) call logged_in with a value, and it'll set
   it, but that would be stupid, and it might not work later
   anyway, so don't.

 Examples:

 my $myspace = new WWW::Myspace;
 unless ( $myspace->logged_in ) {
 	die "Login failed\n";
 }
 
 # This will try forever to log in
 my $myspace;

 do {
    $myspace = new WWW::Myspace( $username, $password );
 } until ( $myspace->logged_in );

=cut

field logged_in => 0;

=head2 error

This value is set by some methods to return an error message.
If there's no error, it returns a false value, so you can do this:

 $myspace->get_profile( 12345 );
 if ( $myspace->error ) {
 	 warn $myspace->error . "\n";
 } else {
 	 # Do stuff
 }

=cut

field 'error' => 0;

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

=head2 browse

XXX - NOT YET FUNCTIONAL

XXX - More debugging needs to be done to ensure accurate
results, and tests need to be added to the test suite for it.
It is working only in Basic search mode, and doesn't seem to
maintain state between pages.  This is not a high-priority
function for me, so if you'd like to help debug/implement it
please do.  Send me a patch and I'll credit you. :)

And now back to your normal docs:

Call browse with a hashref of your search criteria and it
returns a list of friendIDs that match your criteria.

 my @friends = $myspace->browse( {
                   'zipCode' => '91000',
                   'zipRadius' => '20',
                   'Gender' => 'genderWomen', # Pick one of these
                   'Gender' => 'genderMen',
                   'Gender' => 'genderBoth'
                 } );

I'm not sure how I'm going to make the criteria passing easier.
I'm also concerned about your script breaking if they change the
browse form variable names. So maybe I'll add a mapping later.

For now, you have to look at the code for the browse page:

 http://browseusers.myspace.com/browse/Browse.aspx

and get the form variables and possible values from there.

Note that depending on any defaults is dangerous, as this is a strange
form indeed.

=cut

sub browse {

	my ( $criteria ) = @_;

	# Safety check
	croak 'Criteria must be a hash reference\n' unless ref $criteria;

	# We need to set a couple things: Advanced view so we have all
	# the options, and Show Name and Photo Only to list more people
	# per page (for speed).
	$criteria->{'showNamePhotoOnly'} = 'checked';
#	$criteria->{'__EVENTTARGET'} = 'advancedView';
	$criteria->{'__EVENTTARGET'} = 'update';

	# This is a bit of a wacked page, but get_friends
	# handles it with some special case code.
	$self->get_friends( 'browse', $criteria );
	
	# XXX - Try setting __EVENTTARGET to advancedView
	#     - get_friends will stop after 5 pages if $DEBUG
	#     - Sort must preserve state somehow, cookies not working?
	

}

#---------------------------------------------------------------------
# get_friends();
# Return, as an array of friend IDs, all of our friends.
# For each friend page, grep for the "view profile" links, which
# contain the friend IDs.

=head2 get_friends

Returns, as a list of friendIDs, all of your friends. It does not include
Tom, because he's everybody's friend and when you're debugging your band
central CGI page it's probably best to limit your mistakes to
actual friends.

    @friends = $myspace->get_friends;

=cut

sub get_friends {

	my $source="";
	my $source_id = "";
	( $source, $source_id ) = @_;

	# Browse starts at page 1, the rest start at 0.	
	my $page=0; $page++ if ( ( defined $source ) && ($source eq 'browse' ) );

	# Initialize
	my $friends_page="";
	my %friend_ids = ();
	my @friends_on_page = ();
	my ( $id );

	# Loop until we get an empty page or there isn't a "next" link.
	while ( 1 ) {

		# Get the page
		$friends_page = $self->_get_friend_page( $page, $source, $source_id );

		# Grep the friend IDs out
		@friends_on_page = $self->get_friends_on_page( $friends_page->content );
		( $DEBUG ) && print "Done with page $page\n";
		last unless ( @friends_on_page );
#		warn "Got ". @friends_on_page . " friends\n";

		# Add them to the list
		# (This prevents duplicates for inbox, comments, etc)
		foreach $id ( @friends_on_page ) {
			$friend_ids{"$id"}++;
		}

		last unless ( $friends_page->content =~ /">Next<\/a>( |&nbsp;)\&gt;/i );
		
		# Next!
		$self->{_last_friend_page} = $page;
		$page++;
		
		last if ( ( $page > 5 ) && ( $DEBUG ) );
	}

	# Returning an incomplete list of our friends can be dangerous
	# since it's used to do exclusions. Do a
	# safety check. We see if the friend count is within 5% of the
	# number of friends returned (no, myspace's friend counter is never
	# actually right.....)
	unless ( $source ) {
		my @friends = keys( %friend_ids );
		my $friend_count = @friends;
		my $error_allowed = $self->friend_count * .05;
		my $error_offset = abs ( $self->friend_count - $friend_count );
		if ( $error_allowed < 10 ) { $error_allowed = 10 };
		
		if ( $error_offset > $error_allowed ) {
			warn "WARNING: get_friends returned $friend_count friends, ".
			"but should have returned around " . $self->friend_count . ".";
		}
	}

	# If the source is a user's profile, delete the user's friendID from
	# the returned list.
	if ( ( defined $source ) && ( $source eq 'profile' ) ) {
		delete $friend_ids{$source_id};
	}

	# Return the list
	if ( $DEBUG ) {
		my @friends = keys( %friend_ids );
		print "get_friends got " . @friends . " friends\n";
	}
	
	# Return our findings
	return ( sort( keys( %friend_ids ) ) );
}

#---------------------------------------------------------------------
# friends_from_profile( friend_id );

=head2 friends_from_profile( friend_id )

Returns a list of the friends of the profile specified by friend_id.
If passed a list of friend IDs, scans each profile and returns a sorted,
unique list of friendIDs.  Yes, that means if you pass 5 friendIDs and
they have friends in common, you'll only get each friendID once.
You're welcome.

 Examples:
 
 # Band 12345 and 54366 sound like us, get their friends list
 @similar_bands_friends=$myspace->( 12345, 54366 );

=cut

sub friends_from_profile {
	my ( @profiles ) = @_;
	my @friends = ();
	my $id;
	my %friend_ids = ();

	foreach $id ( @profiles ) {
		push ( @friends, $self->get_friends( 'profile', $id ) )
	}
	
	# Sort and return
	foreach $id ( @friends ) {
		$friend_ids{"$id"}=1;
	}
	
	return ( sort( keys( %friend_ids ) ) );
}

#---------------------------------------------------------------------
# friends_who_emailed();
# Return a list of friends with mail in the inbox.

=head2 friends_who_emailed

Returns, as a list of friend IDs, all friends with messages
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
	my $res;
	my $success;
	my $verify_re = '';
	$source = '' unless defined $source;

	# Get the URL-ized version of the user_name
	unless ( defined $self->{_user_name_encoded} ) {
		$self->{_user_name_encoded} = $self->user_name;
		$self->{_user_name_encoded} =~ 
			s/([^A-Za-z0-9 .,%\/])/"%".unpack("H2", $1)/eg;
	}
	
	# Set the URL string for the right set of pages
	if ( $source eq "inbox" ) {
		$url = $MAIL_INBOX_URL . $page;
	} elsif ( $source eq "group" ) { 
		$url = "http://groups.myspace.com/index.cfm?fuseaction=".
			"groups.viewMembers&groupID=${id}&page=${page}";
	} elsif ( $source eq 'browse' ) {
		# This page is weird. It's one big form, and the page number
		# is just part of the form. So the first time, we just get
		# the form, and the rest we just update the page number.
		# Oh, and we start at page 1 instead of 0.
		if ( $page == 1 ) {
			# First time through we load the browse form and submit to
			# specify our options.
			$success = $self->submit_form(
				$BROWSE_PAGE, 1, 'update', $id,
				'Browse Users', 'Browse Users',
				'http://browseusers.myspace.com/browse/');
		} else {
			# Then simply update the page number and submit the form
			$id->{'Page'} = $page;
			$success = $self->submit_form(
				$self->current_page, 1, 'update', $id,
				'Browse Users', 'Browse Users',
				'http://browseusers.myspace.com/browse/' );
		}

		$res = $self->current_page;

	} else {
		$verify_re = "View All Friends";
		( $DEBUG ) && print "Loading friend page $page\n";
		# Unless they specified a profile to get friends from,
		# use our own.
		unless ( $source eq 'profile' ) {
			$id = $self->my_friend_id;
		}

		if ( $page == 0 ) {
			# First page
			$url = "http://home.myspace.com/index.cfm?".
				"fuseaction=user.viewfriends&".
				"friendID=" . $id . "&";
#				"FriendCount=" . $self->friend_count . "&" .
#				"userName=" . $self->user_name;
#			warn "Processing friendID " . $id . "\n";
		} else {
			# Subsequent pages
			$url = "http://home.myspace.com/index.cfm?".
				"fuseaction=user.viewfriends&".
				"friendID=" . $id . "&" .
				"friendCount=" . $self->{_friend_count} . "&" .
				"userName=" . $self->{_user_name} . "&" .
				"page=" . $page . "&" .
				"prevPage=" . $self->{_last_friend_page} . "&" .
				"PREVPageFirstONERETURENED=" . $self->{_low_friend_id}."&".
				"PREVPageLASTONERETURENED=" . $self->{_high_friend_id} . "&";
#				"f_search=&searchby=&" . 
#				"lastpageofset=" . $self->{_total_friend_pages} . "&".
#				"TotalRecords=" . $self->friend_count;
		}

#			warn "processing page $url\n";
	}

	# Get the page
	unless ( $source eq 'browse' ) {
		( $DEBUG ) && print "  Getting URL: $url\n";
		$res = $self->get_page( $url, $verify_re );
		# Save info if we need to
		$self->$save_friend_info if  (
			( ( $source eq '' ) || ( $source eq 'profile' ) ) &&
			( $page == 0 ) );
	}

	return $res;
}

#---------------------------------------------------------------------
# save_friend_info
# We need to grab some info off the View Friends page to feed back
# to subsequent pages.

my sub save_friend_info {

	# Get and store the friend count and user name
	# Friend count
	$self->current_page->content =~ /name="friendCount" value="([0-9]+)"/i;
	$self->{_friend_count} = $1;
	
	# User name
	$self->current_page->content =~ /name="userName" value="([^"]*)"/i;
	$self->{_user_name} = $1;
	
#	warn "Stored friend count " . $self->{_friend_count} . ", ".
#		"user name " . $self->{_user_name} . ".\n";
	
}

#---------------------------------------------------------------------

=head2 get_page( $url, [ $regexp ] )

get_page returns a referece to a HTTP::Response object that contains
the web page specified by $url.

Use this method if you need to get a page that's not available
via some other method. You could include the URL to a picture
page for example then search that page for friendIDs using
get_friends_on_page.

get_page will try up to 20 times until it gets the page, with a 2-second
delay between attempts. It checks for invalid HTTP response codes,
and known Myspace error pages. If called with the optional regexp,
it will consider the page an error unless the page content matches
the regexp. This is designed to get past network problems and such.

EXAMPLE

    The following displays the HTML source of MySpace.com's home
    page.
    my $res=get_page( "http://www.myspace.com/" );
    
    print $res->content;

=cut

sub get_page {

	my ( $url, $regexp ) = @_;

	# Reset error
	$self->error( 0 );

	# Get our web browser object
	my $mech = $self->{mech}; # For readability...

	# Try to get the page 20 times.
	my $attempts = 20;
	my $res;
	do {

		# Try to get the page
		$res = $mech->get("$url");
		$attempts--;

	} until ( ( $self->_page_ok( $res, $regexp ) ) || ( $attempts <= 0 ) );

	# We both set "current_page" and return the value.
	$self->{current_page} = $res;
	return ( $res );

}

#---------------------------------------------------------------------
# _page_ok( $response, $regexp )
# Takes a UserAgent response object and checks to see if the
# page was sucessfully retreived, and checks the content against
# known error messages (listed at the top of this file).
# If passed a regexp, it will return true ONLY if the page content
# matches the regexp (instead of checking the known errors).
# It will delay 2 seconds if it fails so you can retry immediately.
# Called by get_page and submit_form.
# Sets the internal error method to 0 if there's no error, or
# to a printable error message if there is an error.

sub _page_ok {
	my ( $res, $regexp ) = @_;

	# Reset error
	$self->error(0);

	# Check for errors
	my $page_ok = 1;
	my $page;

	if ( $res->is_success ) {

		# Page loaded, but make sure it isn't an error page.
		$page = $res->content; # Get the content
		$page =~ s/[ \t\n\r]+/ /g; # Strip whitespace

		if ( $regexp ) {
			# Page must match the regexp
			unless ( $page =~ /$regexp/i ) {
				$page_ok = 0;
				$self->error("Page doesn't match verification pattern.");
#				warn "Page doesn't match verification pattern.\n";
			}
		} else {
			foreach my $error_regexp ( @ERROR_REGEXPS ) {
				if ( $page =~ /$error_regexp/i ) {
					$page_ok = 0;
					$self->error( "Got error page." );
#					warn "Got error page.\n";
					last;
				}
			}
		}

	} else {

		$self->error("Error getting page: \n" .
			"  " . $res->status_line);

#		warn "Error getting page: \n" .
#			"  " . $res->status_line . "\n";
#		$page_ok = 0;

	}

	sleep 2 unless ( $page_ok );

	return $page_ok;

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
# - We filter out 6221, Tom's ID...

=head2 get_friends_on_page( $friends_page );

This routine takes the SOURCE CODE of an HTML page and returns
a list of friendIDs for which there are profile
links on the page. This routine is used internally by "get_friends"
to scan each of the user's "View my friends" pages.

Notes:
 - It does not return our friendID.
 - friendIDs are filtered so they are unique (i.e. no duplicates).
 - We filter out 6221, Tom's ID.

EXAMPLE:

List the friendIDs mentioned on Tom's profile:
    
    use WWW::Myspace;
    my $myspace = new WWW::Myspace;

    $res = $myspace->get_profile( 6221 );
    
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
	
	if ( $DEBUG ) {
		my @friends = keys( %friend_ids );
		print "  Got " . @friends . " friends on page\n";
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

	return $self->get_page( "${VIEW_PROFILE_URL}${friend_id}",
		$VERIFY_GET_PROFILE );

}

#---------------------------------------------------------------------

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

See also the WWW::Myspace::Comment module that installs with the
distribution.

=cut

sub post_comment {

	my ( $friend_id, $message, $captcha_response ) = @_;
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

	unless ( $captcha_response ) {
		# Convert newlines (\n) into socket-ready CRLF ASCII characters.
		# This also takes care of possible literal "\n"s that come
		# from command-line arguments.
		$message =~ s/(\n|\\n)/\015\012/gs;
	
		# Submit the comment to $friend_id's page
		( $DEBUG ) && print "Getting comment form..\n";
		$submitted = 
			$self->submit_form( "${VIEW_COMMENT_FORM}${friend_id}", 1,
							"", { 'f_comments' => "$message" }, '', 'f_comments'
						);
		
		# If we posted ok, confirm the comment
		if ( $submitted ) {
		
			# See if there's a CAPTCHA response required, if so,
			# fail appropriately.
			if ( $self->current_page->content =~ /$CAPTCHA/i ) {
				$self->captcha( "$1" );
				return "FC";
			}
			
			# Check for the "not your friend" error
			if ( $self->current_page->content =~ /$NOT_FRIEND_ERROR/ ) {
				return "FF";
			}
	
			# Otherwise, confirm it.
			( $DEBUG ) && print "Confirming comment...\n";
			$submitted = $self->submit_form( $self->current_page, 1, "",
					{} );
		}
	} else {
		# Post the confirmation
		$submitted = $self->submit_form( $self->current_page, 1, '',
			{ 'CAPTCHAResponse' => $captcha_response } );
	}

	# Get the resulting page and clean it up (strip whitespace)
	my $page = $self->current_page->content;
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

=head2 captcha

If post_comment returns "FC", the "captcha" method will return
the URL to the CAPTCHA image that contains the text that the
user must enter to post the comment.

 Psuedo-code example of how you can use this in a CGI script:

 my $response = $myspace->post_comment( 12345, 'This is a message' );
 if ( $response eq 'FC' ) {
 	# Get and display the image
 	print '<form>\n'.
 	  "<img src='" . $myspace->captcha . "'>\n".
      '<input type=text name=\'CAPTCHAResponse\'>' .
      '<input type=submit>' .
      '</form>';
 }

 # Post the comment
 $myspace->post_comment( 12345, 'This is a message', $captcha_response );

 (Use in a CGI script is currently problematic since you'll lose the
 Myspace object. I'll try to write a better example later. You could
 try doing a YAML Dump and Load of the $myspace object...)

=cut

field 'captcha';

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

By default it will scan the user's profile page for a previous comment
(by searching for your profile URL on the page, which also detects
you if you're in their top 8 or otherwise linked to from their page).

If called in the second form, it forgoes this duplicate checking
(ignores duplicates), and posts anyway.

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
		if ( ( $attr->{'ignore_dup'} ) ||
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
	  unless ( $myspace->already_commented( $friend_id ) ) {
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

	# If we got an error, return a false true (but error is set)
	return 1 if $self->error;

	# If $self->my_friend_id isn't set for some reason, this'll return
	# a false "true", so set error.
	if ( $self->my_friend_id ) {
		$self->error(0)
	} else {
		$self->error( "my_friend_id is not set!" )
	}

	# Set up our regular expression. We're looking for the link code
	my $regexp = $FRIEND_REGEXP . $self->my_friend_id;

	# If the link's on their page, return true, otherwise return false.	
	if ( $page =~ /${regexp}/i ) {
		return 1
	} else {
		return 0;
	}

}

=head2 inbox

Returns a reference to an array of hash references that contain data
about the messages in your Myspace message inbox. The hashes contain:

 sender (friendID)
 status (Read, Unread, Sent, Replied)
 message_id (The unique ID of the message)
 subject (The subject of the message)

The messages are returned IN ORDER with the newest first to oldest last
(that is, the same order in which they'd appear if you were looking through
your inbox).

I'm sure reading that first line made you as dizzy as it made me typing it.
I think this says it all much more clearly:

 EXAMPLE
 
 # This script displays the contents of your inbox.
 use WWW::Myspace;

 $myspace = new WWW::Myspace;
 
 print "Getting inbox...\n";
 my $messages = $myspace->inbox;

 # Display data for each message 
 foreach $message ( @{$messages} ) {
   print "Sender: " . $message->{sender} . "\n";
   print "Status: " . $message->{status} . "\n";
   print "messageID: " . $message->{message_id} . "\n";
   print "Subject: " . $message->{subject} . "\n\n";
 }

(This script is in the sample_scripts directory, named "get_inbox").

=cut

sub inbox {

	my $page="";
	my $page_no = 0;
	my @messages = ();

	# Loop until we get an empty page or there isn't a "next" link.
	while ( 1 ) {

		# Get the page
		$page = $self->get_page( $MAIL_INBOX_URL . $page_no );

		# Get the message data.

		push @messages, $self->_get_messages_from_page( $page->content );

		last unless ( $page->content =~ /">Next<\/a>( |&nbsp;)\&gt;/i );
		
		# Next!
		$page_no++;
		
	}

	return \@messages;

}

# Take a page, return a list of message data
sub _get_messages_from_page {

	my ( $page ) = @_;
	my @messages = ();
	while ( $page =~
			s/.*?UserID=([^;]+);.*?(Unread|Read|Sent|Replied).*?messageID=([^&]+)&.*?>([^<]+)<//sm ) {
		push @messages, { sender => $1, status => $2, message_id => $3, subject => $4 }
	}
	
	return @messages;
}

=head2 read_message( message_id )

Returns a hashref containing the message identified by message_id.

 my $message_ref = $myspace->read_message( 123456 );
 
 print 'From: ' . $message_ref->{'from'} . .'\n' . # Friend ID of sender
       'Date: ' . $message_ref->{'date'} . .'\n' . # Date (as formatted on Myspace)
       'Subject: ' . $message_ref->{'subject'} .'\n' .
       'Body: ' . $message_ref->{'body'} . '\n';   # Message body

=cut

sub read_message {

	my ( $message_id ) = @_;

	my %message = ();
	my $res = $self->get_page( $READ_MESSAGE_URL . $message_id );
	return \%message unless $res->is_success;

	# If we were passed a bad message ID, we'll have the inbox again
	if ( $res->content =~ /<td><font size="2"><b>Mail Center<br>Inbox<\/b><\/font>/ ) {
		warn "Invalid Message ID\n";
		return \%message;
	}

	# Now we have to yank data out of a messy page.
	my $page = $res->content;
	$page =~ s/[ \t\n\r]+/ /g; # Strip whitespace

	# From:
	$page =~ /From:.*?friendID=([0-9]+)[^0-9]/;
	$message{'from'} = $1;

	# Date:
#	$page =~ /Date:.*?> ?([^<]+) ?</;
#	$page =~ /(Date:.*?> [^<]+ <)/;
	$page =~ /Date:.*?> ([^<]+) </;
	$message{'date'} = $1;
	
	# Subject:
	$page =~ /Subject:.*?>([^ <][^<]+)</;
	$message{'subject'} = $1;

	# Body:
	# (This takes the lines between the span with the special CSS class that
	# starts the message, and the three <br> tags in a row that end the
	# message)
#	$res->content =~ /<span class="blacktextnb10">.*^(.*)^							<br><br><br>/sm;
	$res->content =~ /<span class="blacktextnb10">.*?^(.*)^[ \t]+<br><br><br>/sm;
	$message{'body'} = $1;
	
	# Clean up newlines
	$message{'body'} =~ s/[\n\r]/\n/g;

	# Gotta clean white space before and after the body
	$message{'body'} =~ s/^[ \t\n]*//s;  # Before
	$message{'body'} =~ s/[ \t\n]*$//s;  # After

	# And they have these big BR tags at the beginning of each line...
	$message{'body'} =~ s/^[ \t]*<BR>[ \t]//mg;

	return \%message;
}


#---------------------------------------------------------------------

=head2 reply_message( $message_id, $reply_message )

Warning: This is a new, un-tested method.  If you're reading this, it
means I had to release a new version for some reason before I got to
complete the testing and documentation of this method. It "should" work
fine.  Let me know if it does or not.

Reply to message $message_id using the text in the string
$reply_message.

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


 Example:
 my $status = $myspace->reply_message( 1234567, "Thanks for emailing me!" );


=cut

sub reply_message {

	my ( $id, $reply ) = @_;
	my ( $submitted, $message, $reply_message, $page );

	# Fill in the message (this is lazy...)
	$message = $self->read_message( $id );
	$reply_message = $reply . $message;

	# Convert newlines (\n) into socket-ready CRLF ASCII characters.
	# This also takes care of possible literal "\n"s that come
	# from command-line arguments.
	# (Note that \n does seem to work, but this "should" be safer, especially
	# against myspace changes and platform differences).
	$reply_message =~ s/(\n|\\n)/\015\012/gs;
	
	# First load the message and click "Reply" (first button - it has no
	# name so this'll break if they change the button order).
	$submitted = $self->submit_form( "$READ_MESSAGE_URL", 1, '', {},
		"Read Mail", '' );

	# See if we can mail or if there's an error.
	if ( $submitted ) {
		$page = $self->current_page->content;
		$page =~ s/[ \t\n\r]+/ /g;
		if ( $page =~ /${MAIL_PRIVATE_ERROR}/i ) {
			return "FF";
		} elsif ( $page =~ /${MAIL_AWAY_ERROR}/i ) {
			return "FA";
		}
	} else {
		return "FN";
	}
	
	# Post the reply
	$submitted = $self->submit_form( $self->current_page, 1, '',
		{ 'mailbody' => $reply_message } );

	# Verify and return the appropriate code.
	$page = $self->current_page->content;
	$page =~ s/[ \t\n\r]+/ /g;

	# Return the result
	if (! $submitted ) {
		return "FN";
	} elsif ( $page =~ /$VERIFY_MESSAGE_SENT/ ) {
		return "P";
	} elsif ( $page =~ /$EXCEED_USAGE/i ) {
		return "FE";
	} elsif ( $page =~ /$CAPTCHA/ ) {
		return "FC";
	} else {
		return "F";
	}

#	my ( $url, $form_no, $button, $fields_ref, $regexp1, $regexp2, $base_url ) = @_;

}


#---------------------------------------------------------------------

=head2 send_message( $friend_id, $subject, $message, $add_friend_button )

Send a message to the user identified by $friend_id. If $add_friend_button
is a true value, HTML code for the "Add to friends" button will be added at
the end of the message.

 $myspace->send_message( 6221, 'Hi Tom!', 'Just saying hi!', 0 );

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

See also WWW::Myspace::Message, which installs along with the
distribution.

=cut

sub send_message {

	my ( $friend_id, $subject, $message, $atf ) = @_;
	my ( $submitted, $res, $page );

	# Add the button if they wanted it.
	if ( ( defined $atf ) && ( $atf ) ) {
		$message .= '<p><a href="' . $ADD_FRIEND_URL .
			$self->my_friend_id . '"><img src="http://i.myspace.com'.
			'/site/images/addFriendIcon.gif" alt="Add as friend"></a>\n';
	}

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

	# Convert newlines (\n) into socket-ready CRLF ASCII characters.
	# This also takes care of possible literal "\n"s that come
	# from command-line arguments.
	# (Note that \n does seem to work, but this "should" be safer, especially
	# against myspace changes and platform differences).
	$message =~ s/(\n|\\n)/\015\012/gs;

	# Submit the message
	$submitted = $self->submit_form( $res,
						1, "",
						{ 'subject' => "$subject",
						  'mailbody' => "$message"
						}
					  );
	
	$page = $self->current_page->content;
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

If approve_friend_requests runs into a CAPTCHA response when posting
comments, it will set $myspace->captcha to the URL of the CAPTCHA
image.  If no CAPTCHA was encountered, $myspace->captcha will be 0.
So you can say:

 if ( $myspace->captcha ) { print "oh no!\n" }

approve_friend_requests will approve all friends wether or not it can
comment them as it approves first, then comments the list of approved
friends.

 EXAMPLES

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
		$page = $self->get_page( $FRIEND_REQUEST_URL,
			'Friend Request Manager' )->content;

		# Get the GUID codes from the page
		@guids = $self->_get_friend_requests( $page );
		
		# Quit if there aren't any.
		last unless ( @guids );

		# Get the friendIDs from the page
		@friends = ( @friends, $self->get_friends_on_page( $page ) );

		# Post approval for any we found
		$self->_post_friend_requests( @guids );

	}

	# Clean up friends (there -could- be duplicates in some circumstances)
	my $captcha=0;
	$self->captcha( 0 ); # Reset captcha so they can check it.
	foreach $id ( @friends ) {
		$friends{"$id"}++;
		# If we're to post a message, and this isn't a duplicate,
		# post a comment to this new friend.
		if ( ( $message ) && ( $friends{"$id"} == 1 ) && ( ! $captcha )) {
			if ( $self->post_comment( $id, $message ) eq "FC" ) {
				$captcha=1;
			}
		}
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
		$res=$self->{mech}->post( $FRIEND_REQUEST_POST,
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

=head2 send_friend_request( $friend_id )

IMPORTANT: THIS METHOD'S BEHAVIOR HAS CHANGED SINCE VERSION 0.25!

Sorry, I hate to break backwards-compatibility, but to keep this
method in line with the rest, I had to. The changes are:
1) It takes only one friend, it will DIE if you give it more
   (mainly to let you know that #2 has changed so your scripts don't
   think they're succeeding when they're not).
2) It no longer returns pass/fail, it returns a status code like
   post_comment.

Send a friend request to the friend identified by $friend_id.

This is the same as going to their profile page and clicking
the "add as friend" button and confirming that you want to add them.

Returns a status code and a human-readable error message:

 FF: Failed, this person is already your friend.
 FN: Failed, network error (couldn't get the page, etc).
 FP: Failed, you already have a pending friend request for this person
 FC: Failed, CAPTCHA response requested.
 P:  Passed! Verification string received.
 F: Failed, verification string not found on page after posting.

After send_friend_request posts a friend request, it searches for
various Regular Expressions on the resulting page and sets the
status code accordingly. The "F" response is of particular interest
because it means that the request went through fine, but none of
the known failure messages were received, but the verification
message wasn't seen either.  This means it -might- have gone through,
but probably not.  Of course, worst case here is you try again.


 EXAMPLES
 
 # Send a friend request and get the response
 my $status = $myspace->send_friend_request( 12345 );
 
 # Send a friend request and print the result
 my ( $status, $result ) = $myspace->send_friend_request( 12345 );
 print "Received code $status: $result\n";
 
 # Send a friend request and check for some status responses.
 my $status = $myspace->send_friend_request( 12345 );
 if ( $status =~ /^P/ ) {
 	print "Friend request sent\n";
 } else {
 	if ( $status eq 'FF' ) {
 		print "This person is already your friend\n";
 	} elsif ( $status eq 'FC' ) {
 		print "Received CAPTCHA image request\n";
 	}
 }

 # Send a bunch of friend requests
 my @posted = ();
 my @failed = ();
 foreach my $friend ( @friends ) {
   print "Posting to $friend: ";
   my $status = $myspace->send_friend_request( $friend )
   
   if ( $status =~ /^P/ ) {
       print "Succeeded\n";
       push ( @posted, $friend );
   } else {
       print "Failed with code $status\n";
       push ( @failed, $friend );
   }
   
   # Stop if we got a CAPTCHA request.
   last if $status eq 'FC';
 }
 # Do what you want with @posted and @failed.
 
 # **************************************************************
 # Send friend requests and process the CAPTCHA (thanks VERY MUCH
 # to Olaf Alders for this code).
 use IO::Prompt;
 use WWW::Myspace;
 
 my $myspace = new WWW::Myspace;
 
 my %status_codes = (
 
     FF  =>  'Failed, this person is already your friend.',
     FN  =>  'Failed, network error (couldn\'t get the page, etc).',
     FP  =>  'Failed, you already have a pending friend request for this person',
     FB  =>  'Failed, this person does not accept friend requests from bands.',
     FC  =>  'Failed, CAPTCHA response requested.',
     P   =>  'Passed! Verification string received.',
     F   =>  'Failed, verification string not found on page after posting.',
 );
 
 my $sleep = 10;

 # pass a list of friend ids to this sub, i.e.:
 &friend_request( $myspace->friends_in_group( 12345 ) ); 
 
 sub friend_request {
 
     my @ids = @_;
 
     foreach my $id ( @ids ) {
 
         my $status = $myspace->send_friend_request( $id );
         ++$status{$status};
 
         print "$id:\t$status\n";
 
         if ($status eq 'FC') {
 
             print "captcha response.  please fill in the form at ".
                "the following url before continuing.\n";
             print "\n\nhttp://collect.myspace.com/index.cfm?". 
                "fuseaction=invite.addfriend_verify&friendID=$id\n\n";
 
             my $continue = prompt "Continue? (y/n)\n", -yn;
 
             unless ($continue) {
                 print "exiting nicely.";
                 last;
             }
 
         }
 
         sleep $sleep;
     }
 
     print "Final status report...\n\n######################\n";
 
     foreach my $key (keys %status_codes) {
         if (exists $status{$key} ) {
             print "$status{$key} $status_codes{$key} ($key)\n";
         }
     }
 
 }


=cut

sub send_friend_request {

	# We had to break backwards compatibilty, so enforce it.
	if ( @_ > 1 ) {
		die 'send_friend_request has been changed. Must use '.
			'send_friend_requests to send to multiple friends.\n'.
			'Also now returns status code instead of true/false.\n'.
			'perldoc WWW::Myspace for info.';
	}

	my ( $friend_id ) = @_;

	my %status_codes = (

		FF	=>	'Failed, this person is already your friend.',
		FN	=>	'Failed, network error (couldn\'t get the page, etc).',
		FP	=>	'Failed, you already have a pending friend request for this person',
		FB  =>  'Failed, this person does not accept friend requests from bands.',
		FA  =>  'Failed, this person requires an email addres or last name to add them',
		FC	=>	'Failed, CAPTCHA response requested.',
		P	=>	'Passed! Verification string received.',
		F	=>	'Failed, verification string not found on page after posting.',

	);

	my $return_code = undef;
	my $page;

	# Get the form
	my $res = $self->get_page( $ADD_FRIEND_URL . $friend_id );

	# Check for network failure
	unless ( $res->is_success ) {
		$return_code='FN';
	}

	# Strip the page for comparisons
	$page = $self->current_page->content;
	$page =~ s/[ \t\n\r]+/ /g;

	# Check for "doesn't accept band"
	if ( ( $self->is_band ) && ( $page =~
			/does not accept add requests from bands/i ) ) {
		$return_code = 'FB';
	}

	# Check for "last name or email" required
	elsif ( $page =~ /only accepts add requests from people he\/she knows/ ) {
		$return_code = 'FA';
	}
	
	# Check for CAPTCHA
	elsif ( $page =~ /CAPTCHA/ ) {
		$return_code = 'FC';
	}

	# Check for "already your friend"
	elsif ( $page =~ /already your friend/i ) {
		$return_code = 'FF';
	}

	# Check for pending friend request
	elsif ( $page =~ /pending friend request/i ) {
		$return_code = 'FP';
	}

	unless ( $return_code ) {
		# Post the add request form
		$res = $self->submit_form(
			$self->current_page, 1, '', {} );
	
		# Check response
		unless ( $res ) {
			$return_code = 'FN';
		}
		
		# Unless we already have a return code, check for REs on the page
		# to see what we got.
		unless ( $return_code ) {
	
			$page = $self->current_page->content;
			$page =~ s/[ \t\n\r]+/ /g;
	
			# Check for success
			if ( $page =~ /An email has been sent to the user/i ) {
				$return_code = 'P';
			}
	
		}	
	}

	# If we still don't have a return code, something went wrong
	unless ($return_code) {
		$return_code = 'F';
	}
 
    return (
		LIST { $return_code, $status_codes{$return_code} }
		STR  { $return_code }
	);
}

=head2 send_friend_requests( @friend_ids )

Send friend requests to multiple friends. Stops if it hits a
CAPTCHA request. Doesn't currently give any indication of
which requests succeeded or failed. Use the code example
above for that.

=cut

sub send_friend_requests {

	foreach my $id ( @_ ) {
		last if $self->send_friend_request( $id ) eq 'FC';		
	}

}

=head2 add_to_friends

Convenience method - same as send_friend_request. This method's here
because the button on Myspace's site that the method emulates
is usually labeled "Add to Friends".

=cut

sub add_to_friends {
	$self->send_friend_request( @_ );
}

=head2 add_as_friend

Convenience method - same as send_friend_request. This method's here
Solely for backwards compatibility. Use add_to_friends or
send_friend_request in new code.

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
			'<FORM ACTION="index.cfm?fuseaction=user.deleteFriend&page=0" '.
			'METHOD="POST">';

		$form .= '<input type="checkbox" name="delFriendID" value="'
			. $id . '">';

		$form .= '<input type="image" border="0" name="deleteAll" '.
			'src="images/btn_deleteselected.gif" width="129" height="20">'.
			'</form>';

		# Turn it into an HTML::Form object
		$f = HTML::Form->parse( $form, 'http://collect.myspace.com/' );

		# Check the checkboxes
		$f->find_input( 'delFriendID' )->check;

		# Submit the form
		my $attempts = 25;
		do {
			$res = $self->{mech}->request( $f->click( 'deleteAll' ) );	
			$attempts--;
		} until ( ( $self->_page_ok( $res ) ) || ( $attempts <= 0 ) );

		unless ( $attempts ) {
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
# submit_form( $url, $form_no, $button, $fields_ref, [ $regexp1 ],
#             [ $regexp2 ] )
# Fill in and submit a form on the specified web page.
# $url is the URL of the page OR a reference to a HTTP::Request object.
# $form_no is the number of the form (starting at 0). i.e. if there
# are 2 forms on the page and you want to submit to the 2nd one, set
# $form_no to "1").
# $button is the name of the button of the form to press.
# $fields_ref is a reference to a hash that contains field names
# and values you want to fill in on the form.
# submit_form returns 1 if it succeeded, 0 if it fails.

=head2 submit_form( $url, $form_no, $button, $fields_ref, [ $regexp1 ],
	[ $regexp2 ] )

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

$regexp1 is an optional Regular Expression that will be used to make
sure the proper form page has been loaded. The page content will
be matched to the RE, and will be treated as an error page and retried
until it matches. See get_page for more info.

$regexp2 is an optional RE that will me used to make sure that the
post was successful. USE THIS CAREFULLY! If your RE breaks, you could
end up repeatedly posting a form. This is used by post_comemnts to make
sure that the Verify Comment page is actually shown.

EXAMPLE

This is how post_comment actually posts the comment:

	# Submit the comment to $friend_id's page
	$self->submit_form( "${VIEW_COMMENT_FORM}${friend_id}", 1, "submit",
						{ 'f_comments' => "$message" }, '', 'f_comments'
					);
	
	# Confirm it
	$self->submit_form( $self->current_page, 1, "submit", {} );

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

	my ( $url, $form_no, $button, $fields_ref, $regexp1, $regexp2, $base_url ) = @_;

	# Initialize our variables
	my $mech = $self->{mech}; # For convenience
	my $res = "";
	my ( $field );
	$base_url = $BASE_URL unless $base_url;
	
	# Get the page
	( $DEBUG ) && print "Getting $url...\n";
	if ( ref( $url ) ) {
		# They gave us a page already
		$res = $url;
	} else {
		$res = $self->get_page( $url, $regexp1 );
		# If we couldn't get the page, return failure.
		return 0 if $self->error;
	}

	# Select the form they wanted, or return failure if we can't.
	# +1 is for backwards-compatibility since WWW::Mechanize starts
	# counting at 1.
	my $forms = $mech->forms;
	return 0 unless ( @{$forms} >= $form_no+1 );

	$mech->form_number( $form_no + 1 );

	# Fill in the fields
	( $DEBUG ) && print "Filling in form.\n";

	$mech->set_fields( %{$fields_ref} );

	# Press the submit button.
	my $attempts = 5;
	do
	{
		if ( $button ) {
			$res = $mech->click_button( "$button" );
		} else {
			$res = $mech->click();
		}

		$attempts--;

	} until ( ( $self->_page_ok( $res, $regexp2 ) ) || ( $attempts <= 0 ) );
	
	# Return the result
	$self->{current_page} = $res;
	return $mech->success;

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

Thanks to:

Tom Kerswill (http://tomkerswill.co.uk) for the friend_url method, which
also inspired the friend_user_name method.

Olaf Alders (http://www.wundersolutions.com) for the human-readable status
codes in send_friend request, for the excellent sample code which provides
a workaround for CAPTCHA responses, and for the friends_from_profile
idea.

=head1 KNOWN ISSUES

=over 4

=item -

Some myspace error pages are not accounted for, such as their new
Server Application error page.  If you know enough about web development
to identify an error page that would return a successful HTTP
response code (i.e. returns 200 OK), but then displays an error message,
please keep an eye out for such pages.
If you get such an error message page, PLEASE EMAIL ME (see BUGS below)
the page content so I can account for it.

=item -

post_comment dies if it is told to post to a friendID that
is not a friend of the logged-in user. (MySpace displays
an error instead of a form).

=item -

delete_friend may fail if the friend is not on the first page of
friends.

=item -

When submit_form is called, if it gets a page that is not a
recognized error page, but does not contain the requested form, it
gives up. This may be causing post_comment to fail too easily.

=item -

If the text used to verify that the profile page has been loaded
changes in the future, get_profile and post_comments will report
that the page hasn't been loaded when in fact it has.

=item -

Something (probably UserAgent getting bad cookie data) is generating
the following warnings when logging in:
 Day too big - 2238936 > 24855
 Sec too big - 2238936 > 11647
 Day too big - 2238936 > 24855
 Sec too big - 2238936 > 11647

These are annoying but don't seem to affect the output.

=back

=head1 TODO

Have 'approve_friends' method check GUIDS after first submit to make
sure the current page of GUIDS doesn't contain any duplicates. This
is to prevent a possible infinite loop that could occur if the
submission of the friend requests fails, and also to signal a warning
if myspace changes in a way that breaks the method.

Add checks to all methods to self-diagnose to detect changes in myspace
site that break this module.

Move add_friends to AddFriends.pm

Add methods to AddFriends.pm to: 1-exlude friends, 2-exclude pending
friends, 3-cache like Comment.pm, 4-exclude friends in the "messaged"
cache file.

Add test to 05-message to send a message, find it with inbox, and check its
contents. Do this in addition to the existing read_message test.

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

IF YOU USE A MAIL SERVICE (or program) WITH JUNK MAIL FILTERING, especially
HOTMAIL or YAHOO, add the bug reporting email address above to your address
book so that you can receive status updates.

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

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Grant Grueninger, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
