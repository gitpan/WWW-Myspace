package WWW::Myspace::Data;

#use Spiffy -Base;
use WWW::Myspace::MyBase -Base;

use Carp qw(croak cluck);
use Class::DBI::Loader;
use Class::DBI;
use Class::DBI::AbstractSearch;
use Config::General;
use Data::Dumper;
use DateTime;
use Params::Validate qw(:types);
use Scalar::Util qw(reftype);

=head1 NAME

WWW::Myspace::Data - WWW::Myspace database interaction

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

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
    
    # initialize the database with MySpace login info
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
which format you are using.  You may choose between YAML and
L<Config::General>.  If you choose not to pass this parameter, it will
default to L<YAML>.

=back

=cut


field 'myspace';

my %default_params = (
    config_file         => 0,
    config_file_format  => { default => 'YAML' },
    db                  => { type => HASHREF },
    myspace             => 0,
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
object. So, if you can switch from user A to user B, without creating a
new object. In order to prevent you from shooting yourself in the foot,
set_account() will die if it is unable to log in to MySpace with the
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
    
    my $account = $self->{'Accounts'}->find_or_create(
        { account_name => $account_name, }
    );
        
    $account->myspace_password( $password );
    $account->my_friend_id( $myspace->my_friend_id );
    my $update = $account->update;
    
    if ( $update ) {
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
    
        my $account = $self->{'Accounts'}->retrieve( 
            my_friend_id => $myspace->my_friend_id,
        );
        
        # tweak this later to create an account automatically
        # rather than croaking
        unless ( $account ) {
            croak "this account does not exist.  call set_account to create it.\n";
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

    my $friend_id  = shift;
    my $myspace    = $self->{'myspace'};
    
    # manage profile in "friends" table
    my $friend = $self->{'Friends'}->find_or_create( 
        { friend_id => $friend_id, }
    );
        
    $friend->user_name( $myspace->friend_user_name( $friend_id ) );
    $friend->url( $myspace->friend_url( $friend_id ) );
    
    if ( $myspace->is_band( $friend_id  ) ) {
        $friend->is_band( 'Y');
    }
    else {
        $friend->is_band( 'N' );
    }
    
    $friend->update;
    
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
    
=cut

sub update_friend {
    
    croak "no db connection" unless ( $self->loader );

    my $friend_id  = shift;
    my $myspace    = $self->{'myspace'};
    my $account_id = $self->get_account( );
    
    # cache profile in "friends" table
    $self->cache_friend( $friend_id );
    
    # map friend to account in "friend_to_account" table
    my $account = $self->{'FriendToAccount'}->find_or_create(
        {   friend_id  => $friend_id,
            account_id => $account_id,
        }
    );
    
    unless ( $account->time ) {
        $account->time( time() );
    }
    
    return $account->update;

}

=head2 update_all_friends( )

update_all_friends is really just a wrapper around update_friend  This
method fetches a complete list of your friends currently listed at
MySpace and makes sure that all myspace users that are friends of your
account are represented in the local "friends" table.  It does not
delete friends which may have been removed from your MySpace account
since your last update.

=cut

sub update_all_friends {
    
    my @friends = $self->{'myspace'}->get_friends;
    # test on 2 ids rather than fetching all friends
    #my @friends = ( '6759473', '1000070' );
    
    foreach my $friend_id ( @friends ) {
        $self->update_friend( $friend_id );
    }

}


=head2 date_stamp( )

A wrapper around DateTime which provides a date stamp to be used when
entries are updated.  This is essentially an internal routine.  When
called internally the time zone is supplied from the value passed to
new().

    my $date_stamp = $data->date_stamp( { time_zone => 'America/Toronto' } );

=cut

sub date_stamp {

    my $param_ref = shift;
    
    my $dt = DateTime->now;
    if ( $param_ref->{'time_zone'} ) {
        $dt->set_time_zone( $param_ref->{'time_zone'} );
    }
    
    return $dt->ymd . ' ' . $dt->hms;

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
        dsn                     => $self->{'db'}->{'dsn'},
        user                    => $self->{'db'}->{'user'},
        password                => $self->{'db'}->{'password'},
        options                 => $options,
        namespace               => 'WWW::Myspace::Data',
        relationships           => 1,
        options                 => { AutoCommit => 1 }, 
        inflect                 => { child => 'children' },      
        additional_classes      => qw/Class::DBI::AbstractSearch/,
        
        #additional_base_classes => qw/My::Stuff/, # or arrayref
        #left_base_classes       => qw/Class::DBI::Sweet/, #
        #constraint              => '^foo.*',    
    );
  
    $self->{'loader'} = $loader;

    my @classes = $loader->classes;

    # each class is now represented in self
    foreach my $class (@classes) {
        my @namespace = split(/::/, $class);
        $self->{$namespace[-1]} = $class;
    }
    
    unless ( $loader ) {
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
     die Dumper(\$self);
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

Please report any bugs or feature requests to
C<bug-www-myspace at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Myspace>.
I will be notified, and then you'll automatically be notified of
progress on
your bug as I make changes.

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

Copyright 2006 Olaf Alders, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;    # End of WWW::Myspace::Data
