package WWW::Myspace::Data;

use WWW::Myspace::MyBase -Base;

use Carp qw(croak cluck);
use Class::DBI::Loader;
use Class::DBI;
use Class::DBI::AbstractSearch;
use Config::General;
use Data::Dumper;
use DateTime;
use DateTime::Format::MySQL;
use Params::Validate qw(:types validate validate_pos);
use Scalar::Util qw(reftype);

=head1 NAME

WWW::Myspace::Data - WWW::Myspace database interaction

=head1 VERSION

Version 0.08

=cut

our $VERSION = '0.08';
my $DEBUG = 0;

=head1 SYNOPSIS

This module is the database interface for the WWW::Myspace modules.  It
imports methods into the caller's namespace which allow the caller to
bypass the loader object by calling the methods directly.  This module
is intended to be used as a back end for the Myspace modules, but it can
also be called directly from a script if you need direct database
access.

    my %db = (
        dsn      => 'dbi:mysql:database_name',
        user     => 'username',
        password => 'password',
    );
    
    # create a new object
    my $data       = WWW::Myspace::Data->new( $myspace, { db => \%db } );
    
    # set up a database connection
    my $loader     = $data->loader();
    
    # initialize the database with Myspace login info
    my $account_id = $data->set_account( $username, $password );
    
    # now do something useful...
    my $update = $data->update_friend( $friend_id );
    
    
=cut

=head1 CONSTRUCTOR AND STARTUP

=head2 new()

new() creates a WWW::Myspace::Data object, based on parameters which are
passed to it.  You can (optionally) pass a valid WWW::Myspace object to
new as the first argument.  If you just want database access, there is
no need to pass the myspace object.  However, most update methods
require a valid login, so it's not a bad idea to pass it if you don't
mind the login overhead.

    my %db = (
        dsn      => 'dbi:mysql:database_name',
        user     => 'username',
        password => 'password',
    );
    
    my $data = WWW::Myspace::Data->new( $myspace, { db => \%db } );
     
Required Parameters

All parameters must be passed in the form of a hash reference.

=over 4

=item * C<< db => HASHREF >>

The db HASHREF can made up of the following 3 parameters:

Required Parameters

=over 4

=item * C<< dsn => $value >>

The dsn is passed directly to L<Class::DBI::Loader>, so whatever
qualifies as a valid dsn for L<Class::DBI> is valid here.

    # for a MySQL database
    'dbi:mysql:database_name'
    
    # Or
    # if you are using SQLite
    'dbi:SQLite:dbname=/path/to/dbfile'    

=back

Optional Parameters

=over 4

=item * C<< user => $value >>
    
This is your database username.  If you're running the script from the
command line, it will default to the user you are logged in as.
    
=item * C<< password => $value >>

Your database password (if any).  If you don't need a password to access
your database, just leave this blank.

=item * C<< time_zone => $value >>

This is any valid L<DateTime> time zone designation.  eg:

    time_zone => 'America/Toronto'

=back

Optional Parameters

=item * C<< config_file => $value >>
 
If you prefer to keep your startup parameters in a file, pass a valid
filename to new.
 
Your startup file may contain any of the parameters that can be passed
to new() (except the $myspace object).  Your config file will be used to
set the default parameters for startup.  Any other parameters which you
also pass to new() will override the corresponding values in the config
file.  So, if you have a default setting for exclude_my_friends in your
config file but also pass exclude_my_friends directly to new(), the
config file value will be overriden.  The default behaviour is not to
look for a config file.  Default file format is L<YAML>.
 
    my $adder = WWW::Myspace::FriendAdder->( 
        $myspace, 
        { config_file => '/path/to/adder_config.cfg', }, 
    );

=item * C<< config_file_format => [YAML|CFG] >>

If you have chosen to use a configuration file, you may state explicitly
which format you are using.  You may choose between L<YAML> and
L<Config::General>.  If you choose not to pass this parameter, it will
default to YAML.

=back

=cut

field 'myspace';

my %default_params = (
    config_file        => 0,
    config_file_format => { default => 'YAML' },
    db                 => { type => HASHREF },
    myspace            => 0,
    time_zone          => 0,
);

const default_options => \%default_params;

=head2 loader( )

Before you do anything, call the loader() method.  This returns the
Class::DBI::Loader object.  Handy if you want to access the database
directly.  If a loader object does not already exist, loader() will try
to create one.

    my $loader = $data->loader();
    
    # get a list of all your friends
    my @friend_objects = WWW::Myspace::Data::Friends->retrieve_all;


=cut

sub loader {

    unless ( $self->{'loader'} ) {
        $self->_loader;
    }

    return $self->{'loader'};

}

=head2 set_account ( $account, $password )

In order to use the database, you'll need to store your account login
information in the accounts table.  This method attempts to log in to
Myspace first.  If successful, your login information will be stored. 
If your account already exists in the accounts table, your password will
be updated to the password supplied to the method.

In order to use this module, you'll have to call this function at least
once.  Once your account has been added to the database, there's no need
to call set_account again, provided you always use the same Myspace
account and you don't change your password information.

This mutator will also allow you to switch accounts within the same
object. So, you can switch from user A to user B, without creating a
new object. In order to prevent you from shooting yourself in the foot,
set_account() will die if it is unable to log in to Myspace with the
username/password you provide.

To prevent any problems, be sure to check the return value.  If
successful, it returns the id of the account.  That is, the id which has
been assigned to this account in the accounts table.  Returns 0 if there
was a problem creating or updating the account.

=cut

sub set_account {

    my $account_name = shift;
    my $password     = shift;

    croak "no db connection" unless ( $self->loader );

    my $myspace = WWW::Myspace->new( $account_name, $password );

    unless ( $myspace->logged_in ) {
        croak "Login failed using: $account_name / $password\n";
    }

    $self->{'myspace'} = $myspace;

    my $account =
      $self->{'Accounts'}
      ->find_or_create( { account_name => $account_name, } );

    $account->myspace_password($password);
    $account->my_friend_id( $myspace->my_friend_id );
    my $update = $account->update;

    if ($update) {
        $self->{'account_id'} = $account->account_id;
        return $account->account_id;
    }
    else {
        return 0;
    }

}

=head2 get_account( )

Returns the account id assigned by the database for the account under
which $myspace is currently logged in.  Mostly useful for internal
stuff, but it's available if you need it.

=cut

sub get_account {

    my $myspace = $self->{'myspace'};

    unless ( $self->{'account_id'} ) {

        my $account =
          $self->{'Accounts'}
          ->retrieve( my_friend_id => $myspace->my_friend_id, );

        # tweak this later to create an account automatically
        # rather than croaking
        unless ($account) {
            croak
"this account does not exist.  call set_account to create it.\n";
        }

        $self->{'account_id'} = $account->account_id;
    }

    return $self->{'account_id'};

}

=head2 cache_friend( $friend_id )

Add this friend id to the friends table.  cache_friend will not create a
relationship between the friend_id and any account. It just logs the
friend information in order to speed up various other operations.  It's
basically an internal method, but you could use it to cache information
about any friend_id that isn't tied to any specific account.  ie if you
are spidering myspace and you just want to collect info on anyone, you
can call this method.

=cut

sub cache_friend {

    croak "no db connection" unless ( $self->loader );
    my $page = $self->{'myspace'}->_validate_page_request( @_ );

    # page fetches are not always succesful.  opting to return here so that
    # friend adding doesn't die on a large list. that's annoying...
    if ( !$page ) {
        warn "could not cache friend - no defined response object provided";
        return;
    }

    my $myspace   = $self->{'myspace'};
    my $friend_id = $myspace->_apply_regex(
        regex => 'friend_id',
        page  => $page,
    );
    
    croak 'friend_id required' unless $friend_id;

    # manage profile in "friends" table
    my $friend = $self->_find_or_create_friend($friend_id);
    
    my $content = $page->content;

    my %profile = ();

    # first, do some generic tests

    # myspace URL
    if ( $content =~
        /\<title\>[\s]*www.myspace\.com\/([\S]*)[\s]*\<\/title\>/ )
    {
        $profile{'url'} = $1;
    }

    # myspace username
    if ( $content =~
/index\.cfm\?fuseaction=user\&circuitaction\=viewProfile_commentForm\&friendID\=[0-9]+\&name\=([^\&]+)\&/
      )
    {
        my $line = $1;
        $line =~ s/\+/ /g;
        $line =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
        $profile{'user_name'} = $line;
    }

    if ( $content =~
/ctl00_Main_ctl00_UserBasicInformation1_hlDefaultImage(.*?Last Login.*?)<br>/ms
      )
    {

        # split the data on line breaks and evaluate it from there
        # band pages have more line breaks than personal pages
        my @lines = split( /<br>/, $1 );

        my $size = @lines;

        # personal profile
        if ( $size == 9 ) {

            $profile{'is_band'} = 'N';

            if ( $content =~ />"(.*?)"</ms ) {
                $profile{'tagline'} = $1;
            }

            $profile{'sex'} = $lines[2];
            if ( $content =~ /(\d{1,}) years old/ ) {
                $profile{'age'} = $1;
            }

            ( $profile{'city'}, $profile{'region'} ) =
              $self->_regex_city( $lines[4] );
            $profile{'country'}    = $lines[5];

        }

        # band profile
        elsif ( $size == 11 ) {

            $profile{'is_band'} = 'Y';

            if ( $content =~ m/Member Since.*?(\d\d\/\d\d\/\d\d\d\d)/ ) {
                $profile{'member_since'} = $self->_regex_date($1);
            }

            if ( $lines[1] =~ /<strong>.*?"(.*?)".*?<\/strong>/ms ) {
                $profile{'tagline'} = $1;
            }

            ( $profile{'city'}, $profile{'region'} ) =
              $self->_regex_city( $lines[3] );
            $profile{'country'} = $lines[4];

            if ( $lines[6] =~ /(\d{1,})/ ) {
                $profile{'profile_views'} = $1;
            }

           

        }

        $profile{'last_login'} = $self->{'myspace'}->last_login_ymd(
            page => $page,
        );
        
        foreach my $key ( keys %profile ) {
            if ( $profile{$key} && $profile{$key} =~ /[0-9a-zA-Z]/ ) {
                $profile{$key} =~ s/\t//g;        # remove tabs
                $profile{$key} =~ s/^\s{1,}//g;   # remove leading whitespace
                $profile{$key} =~ s/\s{1,}$//g;   # remove trailing whitespace
            }
        }

    }

    foreach my $key ( keys %profile ) {
        if ( $profile{$key} && $profile{$key} =~ /[0-9a-zA-Z]/ ) {
            $friend->$key( $profile{$key} );
        }
    }

    $self->{'last_lookup_id'} = $friend_id;

    $friend->last_update( $self->date_stamp );
    return $friend->update;

}

=head2 track_friend

Please note that this function requires an additional database table 
("tracking") has been added to the mysql.txt as of version 0.07  The method 
returns a Class::DBI object representing the row which has just been inserted.

 EXAMPLE
 
 my $tracking = $data->track_friend( friend_id => $friend_id );
 
 OR
 
 my $page = $myspace->get_profile( $friend_id );
 my $tracking = $data->track_friend( page => $page );
 
 print "views: " . $tracking->profile_views . "\n";
 
 print "friends: " . $tracking->friend_count . "\n";
 
 print "comments: " . $tracking->comment_count . "\n";

=cut

sub track_friend {

    croak "no db connection" unless ( $self->loader );
    my $page = $self->{'myspace'}->_validate_page_request( @_ );

    my $myspace   = $self->{'myspace'};
    my $friend_id = $myspace->_apply_regex(
        regex => 'friend_id',
        page  => $page,
    );
    
    croak 'friend_id required' unless $friend_id;

    my $account =
      $self->{'Accounts'}->find_or_create( my_friend_id => $friend_id, );

    my $dt = $self->date_stamp( { format => 'dt' } );

    my $tracking = $self->{'Tracking'}->find_or_create(
        account_id => $account->account_id,
        date       => $dt->ymd,
    );
    
    $tracking->profile_views( $myspace->profile_views( page => $page ) );
    $tracking->friend_count(  $myspace->friend_count( $page ) );
    $tracking->comment_count( $myspace->comment_count( page => $page ) );
    
    $tracking->update;

    return $tracking;

}

=head2 update_friend( $friend_id )

The "friends" table in your local database stores information about
myspace friends, shared among all accounts using your database. This
lets you store additional information about them, such as their first
name, and is also used by WWW::Myspace methods and modules to track
information related to friends.

Basically this method calls cache_friend() and then creates a friend to
account relationship.

update_friend takes a single friend id and makes sure it is represented
in the local "friends" table.  Returns 1 if the entry was successfully
updated.  (Returns Class::DBI return value for the update).

    my $data = new WWW::Myspace::Data( \%config );
    
    $data->update_friend( $friend_id );
    
Optional Parameters

Optionally, using a hash reference as your second parameter, you may supply 
update_friend with "freshness" parameters, to ensure that updates are only 
performed on friend ids which have not been updated since some arbitrary time.  
You would define expired data in the following way:

my %freshness = (
    days => 7,
    hours => 12,
);

$data->update_friend( $friend_id, { freshness => \%freshness } );

This would only update friend_ids which were updated more than 7.5 days ago.  
Available parameters are:

=over 4

=item * C<< years => $value >>

=item * C<< months => $value >>

=item * C<< days => $value >>

=item * C<< hours => $value >>

=item * C<< seconds => $value >>

=back

Each value should be an integer.  If you do not supply freshness criteria the 
default behaviour will be to update the friend regardless of last update time.

=cut

sub update_friend {

    croak "no db connection" unless ( $self->loader );

    validate_pos(
        @_,
        { type => SCALAR },
        { type => HASHREF | UNDEF, optional => 1 }
    );

    my $friend_id  = shift;
    my $arg_ref    = shift;
    my $myspace    = $self->{'myspace'};
    my $account_id = $self->get_account();

    my $friend = $self->_find_or_create_friend($friend_id);

    $self->_add_friend_to_account(
        { friend_id => $friend_id, account_id => $account_id } );

    # if last_update is true, we may not need to update this record
    if ( $friend->last_update && $arg_ref->{'freshness'} ) {

        my $dt_update =
          DateTime::Format::MySQL->parse_datetime( $friend->last_update );

        my $fresh =
          $self->_is_fresh( $dt_update,
            $self->_fresh_after( $arg_ref->{'freshness'} ) );

        # return without updating if data is fresh
        return 0 if $fresh > -1;

    }

    # cache profile in "friends" table
    return $self->cache_friend($friend_id);

}

=head2 update_all_friends( )

update_all_friends is really just a wrapper around update_friend  This
method fetches a complete list of your friends currently listed at
Myspace and makes sure that all myspace users that are friends of your
account are represented in the local "friends" table.  It does not
delete friends which may have been removed from your Myspace account
since your last update.

Just like update_friend, this method also takes "freshness" arguments.  

    $data->update_all_friend( { freshness => \%freshness } )

For more info on freshness parameters, see update_friend()

=cut

sub update_all_friends {

    validate_pos( @_, { type => HASHREF, optional => 1 } );
    my $fresh_ref = shift;

    my @friends = $self->{'myspace'}->get_friends;

    foreach my $friend_id (@friends) {
        $self->update_friend( $friend_id, $fresh_ref );
    }

}

=head2 date_stamp( )

A wrapper around DateTime which provides a date stamp to be used when
entries are updated.  This is essentially an internal routine.  When
called internally the time zone is supplied from the value passed to
new().

Optional Parameters

=over 4

=item * C<< time_zone => $value >>
    
Any valid L<DateTime> time zone, like 'America/Toronto' or
'America/Chicago'.  Defaults to GMT.

=item * C<< epoch => $value >>
    
Any positive number representing seconds since the epoch.  Defaults to 
current system time

    my $date_stamp = $data->date_stamp( 
        { time_zone => 'America/Toronto', epoch => time(), } 
    );

=item * C<< format => 'dt' >>

This option will cause the method to return the actual DateTime object
rather than a string.  Can be handy if you just need a DateTime object and
want it initialized with the proper time zone.

=back

=cut

sub date_stamp {

    my $param_ref = shift;

    my $dt = undef;

    if ( $param_ref->{'epoch'} && $param_ref->{'epoch'} > 0 ) {
        $dt = DateTime->from_epoch( epoch => $param_ref->{'epoch'} );
    }
    else {
        $dt = DateTime->now;
    }

    if ( $param_ref->{'time_zone'} ) {
        $dt->set_time_zone( $param_ref->{'time_zone'} );
    }

    elsif ( $self->{'time_zone'} ) {
        $dt->set_time_zone( $self->{'time_zone'} );
    }

    if ( exists $param_ref->{format} && $param_ref->{'format'} eq 'dt' ) {
        return $dt;
    }

    return $dt->ymd . ' ' . $dt->hms;

}

=head2 is_band( )

Calls is_band_from_cache to see if the friend id is a band profile.  If
it returns undef, the function will look up the info using Myspace.pm's
is_band function, cache the info and return the result.

=cut

sub is_band {

    my $friend_id = shift;

    my $is_band = $self->is_band_from_cache($friend_id);

    # don't return on undef
    if ( defined $is_band ) {
        return $is_band;
    }
    else {
        $self->cache_friend($friend_id);
        $self->{'last_lookup_id'} = $friend_id;
        return $self->is_band_from_cache($friend_id);
    }

}

=head2 is_band_from_cache( )

Checks the database to see if the friend id is a band profile. Returns
undef if the id could not be found or band info is not cached for this
id.

=cut

sub is_band_from_cache {

    my $friend_id = shift;

    my $friend = $self->{'Friends'}->retrieve( friend_id => $friend_id, );

    if ($friend) {

        if ( !$friend->is_band ) {

            # if it's a NULL value, a proper lookup is needed
            return undef;
        }
        elsif ( $friend->is_band eq 'Y' ) {
            return 1;
        }
        elsif ( $friend->is_band eq 'N' ) {
            return 0;
        }

    }
    else {
        return undef;
    }

}

=head2 friends_from_profile( { friend_id => $friend_id } )

This is "sort of" a wrapper around WWW::Myspace->friends_from_profile
The method will first check the database to see if there are any friends
listed for $friend_id.  If friends exist, they will be returned.
Otherwise, the method will call WWW::Myspace->friends_from_profile.  It
will cache the results, perform a database lookup and then return the
results to the caller.  Aside from speeding up lookups, this allows you
to do some fancier limiting and sorting when requesting data.  This
method doesn't take all of the arguments that the Myspace module takes,
so please read the docs carefully.

Required Parameters

=over 4

=item * C<< friend_id => $friend_id >>

A valid Myspace friend id.

=back

Optional Parameters

=over 4

=item * C<< refresh => [0|1] >>

Skip the database access and force the method to do a new lookup on the
Myspace site.  This is useful if you want to add any new friend ids
which may have been added since you last ran this method.  Because the
data that Myspace.com returns can't be trusted, friends missing from a
previous list will *not* be deleted from the cache.

=item * C<< limit => $value >>

Limit the number of friends returned to some positive integer.  By
default, no LIMIT is applied to queries.

=item * C<< offset => $value >>

Used for OFFSET argument in a query.  Must be used in tandem with the limit 
parameter.  Offset will set the amount of entries which should be skipped 
before returning values.  For example:

    # Only return 500 results, beginning after the first 10
    my @friend_ids = $data->friends_from_profile( { 
        friend_id   => $my_friend_id,
        limit       => 500,
        offset      => 10,
    } );

=item * C<< order_column => [friend_id | friend_since] >>

The column by which to order returned results.  Defaults to "friend_id".

=item * C<< order_direction => [ASC | DESC] >>

The direction by which to sort results. ASC (ascending) or DESC
(descending).  Defaults to ASC.

=back

So, for example, if you're starting from scratch and you want to start
with a complete list of your own friends in the database, you can do
something like this:

    $data->set_account ( $account, $password );
    my @friend_ids = $data->friends_from_profile( { 
        friend_id => $my_friend_id 
    } );

This will cache all of your friends by their id numbers.  Because of
speed concerns, it will not cache any other info about them.  If you
want more info on each friend, just add the following call:

    foreach my $friend_id ( @friend_ids ) {
        $data->cache_friend( $friend_id );
    }

Here's how you might call this method using all available parameters:

    my @friends = $data->friends_from_profile( { 
        friend_id       =>  $friend_id, 
        refresh         =>  0, 
        limit           =>  100,
        offset          =>  50,
        order_direction =>  'DESC',
        order_column    =>  'friend_id',
    } );


=cut

sub friends_from_profile {

    my $arg_ref = shift;

    my %args   = %{$arg_ref};
    my @params = %args;

    my %params = validate(
        @params,
        {
            friend_id => {
                type     => SCALAR,
                optional => 0,
            },

            refresh => {
                type     => SCALAR,
                default  => 0,
                optional => 1,
            },

            limit => {
                type     => SCALAR,
                default  => 0,
                optional => 1,
            },

            offset => {
                type     => SCALAR,
                default  => 0,
                optional => 1,
                depends  => ['limit'],
            },

            order_column => {
                type     => SCALAR,
                default  => 'friend_id',
                optional => 1,
            },

            order_direction => {
                type     => SCALAR,
                default  => 'ASC',
                optional => 1,
            },

        }
    );

    if ( $params{'offset'} && !$params{'limit'} ) {
        croak "You must supply a 'limit' param if you supply 'offset'";
    }

    my $friend_id = $params{'friend_id'};

    # first check if the id exists in the accounts table
    my $account =
      $self->{'Accounts'}->find_or_create( my_friend_id => $friend_id, );

    my $account_id = $account->account_id;
    $params{'account_id'} = $account_id;

    my @friend_ids = ();

    unless ( $arg_ref->{'refresh'} ) {

        @friend_ids = $self->_friends_from_profile( \%params );
        return @friend_ids if @friend_ids;

    }

    # if nothing has been cached, we need to fetch the stuff "old school"
    my @lookup_ids = $self->{'myspace'}->friends_from_profile(
        id        => $friend_id,
        max_count => $arg_ref->{'limit'},
    );

    foreach my $id (@lookup_ids) {

        my $friend = $self->_find_or_create_friend($id);

        my $friend_to_account =
          $self->_add_friend_to_account(
            { friend_id => $id, account_id => $account_id } );

    }

    @friend_ids = $self->_friends_from_profile( \%params );
    return @friend_ids;

}

=head2 approve_friend_requests

A wrapper around Myspace::approve_friend_requests.  Calls this method and
then logs the friend requests which have been accepted.  Returns the list of
friend_ids which have been approved.

=cut

sub approve_friend_requests {
    
    my @friend_ids = $self->{'myspace'}->approve_friend_requests( @_ );
    my $account_id = $self->get_account();
    
    #my @friend_ids = ( 1 );
    
    foreach my $friend_id ( @friend_ids ) {
        my $insert = WWW::Myspace::Data::AcceptLog->insert( {
            account_id      => $account_id,
            friend_id       => $friend_id,
            last_accept     => $self->date_stamp,
        } );
        
        print Dumper $insert if $DEBUG;
    }
        
    return @friend_ids;
    
}

=head2 post_comment

A wrapper around Myspace::post_comment.  Calls this method and
then logs the comment details.  Returns the return value of 
Myspace::post_comment

=cut

sub post_comment {
    
    my $status      = $self->{'myspace'}->post_comment( @_ );
    my $friend_id   = shift;
    my $account_id  = $self->get_account();
    
    my $insert = WWW::Myspace::Data::CommentLog->insert( {
        account_id      => $account_id,
        friend_id       => $friend_id,
        result_code     => $status,
        last_comment    => $self->date_stamp,
    } );
        
    print Dumper $insert if $DEBUG;
        
    return $status;
    
}

=head2 send_message( %options )

A wrapper around Myspace::send_message.  Calls this method and
then logs the message details.  Returns the return value of 
Myspace::send_message  This method accepts the %options hash -- not the 
positional parameters.

=cut

sub send_message {
    
    my $status = $self->{'myspace'}->send_message( @_ );
    my $account_id = $self->get_account();
    
    my %args = @_;
    
    my $insert = WWW::Myspace::Data::MessageLog->insert( {
        account_id      => $account_id,
        friend_id       => $args{'friend_id'},
        result_code     => $status,
        last_message    => $self->date_stamp,
    } );
        
    print Dumper $insert if $DEBUG;
        
    return $status;
    
}

=head2 get_last_lookup_id ( )

Returns the friend id of the last id for which a Myspace.pm 
lookup was performed.  This is used by FriendAdder.pm to determine
whether to sleep after skipping a profile.  If the lookup did not extend
beyond the database, there's no reason to sleep.  May be useful for
troubleshooting as well.

=cut

sub get_last_lookup_id {

    return $self->{'last_lookup_id'};

}

=head2 is_cached( $friend_id )

Returns 1 if this friend is in the database, 0 if not.

=cut

sub is_cached {

    my $friend_id = shift;

    my $friend = $self->{'Friends'}->retrieve( friend_id => $friend_id, );

    if ($friend) {
        return 1;
    }
    else {
        return 0;
    }

}

=head2 _loader( )

This is a private method, which creates a Class::DBI::Loader object,
based on configuration parameters passed to new()  To access the loader
object directly, use loader()


=cut

sub _loader {

    my $options = {
        RaiseError => 1,
        AutoCommit => 0,
    };

    #die Dumper($self);

    my $loader = Class::DBI::Loader->new(
        dsn                => $self->{'db'}->{'dsn'},
        user               => $self->{'db'}->{'user'},
        password           => $self->{'db'}->{'password'},
        options            => $options,
        namespace          => 'WWW::Myspace::Data',
        relationships      => 1,
        options            => { AutoCommit => 1 },
        inflect            => { child => 'children' },
        additional_classes => qw/Class::DBI::AbstractSearch/,

        #additional_base_classes => qw/My::Stuff/, # or arrayref
        #left_base_classes       => qw/Class::DBI::Sweet/, #
        #constraint              => '^foo.*',
    );

    $self->{'loader'} = $loader;

    my @classes = $loader->classes;

    # each class is now represented in self
    foreach my $class (@classes) {
        my @namespace = split( /::/, $class );
        $self->{ $namespace[-1] } = $class;
    }

    unless ($loader) {
        croak "could not make a database connection\n";
    }

    return $loader;

}

=head2 _die_pretty( )

Internal method that deletes the Myspace object from $self and then
prints $self via Data::Dumper.  The Myspace object is so big, that when
you get it out of the way it can be easier to debug set parameters.

    $adder->_die_pretty;

=cut

sub _die_pretty {

    delete $self->{'myspace'};
    die Dumper( \$self );
}

=head2 _add_friend_to_account ( { friend_id => $friend_id, account_id => $account_id } )

Internal method.  Maps a friend to an account id in the db.

=cut 

sub _add_friend_to_account {

    my $param_ref = shift;

    croak 'friend_id required'  unless $param_ref->{'friend_id'};
    croak 'account_id required' unless $param_ref->{'account_id'};

    # map friend to account in "friend_to_account" table
    my $account = $self->{'FriendToAccount'}->find_or_create(
        {
            friend_id  => $param_ref->{'friend_id'},
            account_id => $param_ref->{'account_id'},
        }
    );

    if ( $account->friend_since eq '0000-00-00 00:00:00' ) {
        $account->friend_since( $self->date_stamp );
    }

    return $account->update;

}

=head2 _find_or_create_friend( $friend_id )

Internal method.  Adds friend id to db, but does not associate friend
with any account.

=cut 

sub _find_or_create_friend {

    my $id = shift;

    my $friend = $self->{'Friends'}->find_or_create( { friend_id => $id, } );

    return $friend;

}

=head2 _friends_from_profile( $friend_id )

Internal method.  Checks db for cached friends.

=cut 

sub _friends_from_profile {

    my $param_ref  = shift;
    my %params     = %{$param_ref};
    my @friend_ids = ();
    my $order_col  = "$params{'order_column'} $params{'order_direction'}";

    my $search_params = {
        limit_dialect => $self->{'FriendToAccount'},
        order_by      => $order_col,
    };

    foreach my $param ( 'limit', 'offset' ) {
        if ( $params{$param} ) {
            $search_params->{$param} = $params{$param};
        }
    }

    my $iterator =
      $self->{'FriendToAccount'}
      ->search_where( { account_id => $params{'account_id'} },
        $search_params, );

    while ( my $friend = $iterator->next ) {

        push( @friend_ids, $friend->friend_id );

    }

    return @friend_ids;

}

=head2 _fresh_after ( { days => $value } )

Internal method.  Returns a DateTime object for time/data comparisons. 
See update_friend for arguments that _fresh_after takes.

=cut 

sub _fresh_after {

    my $arg_ref = shift;

    my %args   = %{$arg_ref};
    my @params = %args;

    my %params = validate(
        @params,
        {
            years   => { default => 0 },
            months  => { default => 0 },
            days    => { default => 0 },
            hours   => { default => 0 },
            minutes => { default => 0 },
            seconds => { default => 0 },
        }
    );

    my $dt = DateTime->now;
    $dt->set_time_zone( $self->{'time_zone'} ) if ( $self->{'time_zone'} );

    # get fresh-by date
    $dt->subtract(%params);

    return $dt;

}

=head2 _is_fresh( $last_update_time, $fresh_after_time )

Internal method.  Returns true if data is still "fresh", meaning that
the cached information does not need an update.

=cut

sub _is_fresh {

    # compare the dates
    # data is fresh if $dt_update is greater than $dt
    # that scenario retuns a 1
    validate_pos( @_, { isa => 'DateTime' }, { isa => 'DateTime' } );

    return DateTime->compare(@_);

}

=head2 _regex_city ( $content )

Internal method.  Regex to find City/Region data.

=cut 

sub _regex_city {

    my $content = shift;
    my $region  = undef;

    my @city = split( /,/, $content );
    my $city = shift @city;

    if (@city) {
        $region = join( ",", @city );
    }

    return ( $city, $region );
}

=head2 _regex_date ( $content )

Internal method.  Regex to return last login time.

=cut 

sub _regex_date {

    my $content = shift;

    if ( $content =~ m/(\d{1,2})\/(\d{1,2})\/(\d\d\d\d)/ms ) {
        return $3 . '-' . $2 . '-' . $1;
    }

}

=head1 DATABASE SCHEMA

You'll find the database schema in a file called mysql.txt in the top
directory after untarring WWW::Myspace.  This is a dump of the MySQL db
from phpMyAdmin.  It can easily be altered for other database formats
(like SQLite).  You can import the schema directly from the command
line:

mysql -u username -p databasename < mysql.txt

You may also use a utility like phpMyAdmin to import this file as SQL.

Keep in mind that the schema hasn't been 100% finalized and is subject
to change.


=head1 AUTHOR

Olaf Alders, C<< <olaf at wundersolutions.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-myspace at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Myspace>. I will be
notified, and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 NOTES

This module is still in its infancy.  It does a lot of cool stuff, but
the interface is still subject to change.  Please keep this in mind when
upgrading

=head1 TO DO

This module is in developer mode.  We still need to finalize a database
schema and integrate it fully with the other WWW::Myspace modules.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Myspace::Data

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

Many thanks to Grant Grueninger for giving birth to WWW::Myspace and for
his help and advice in the development of this module.

=head1 COPYRIGHT & LICENSE

Copyright 2006-2007 Olaf Alders, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;    # End of WWW::Myspace::Data
