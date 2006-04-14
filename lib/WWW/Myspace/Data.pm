package WWW::Myspace::Data;

#use Spiffy -Base;
use WWW::Myspace::MyBase -Base;

use Carp qw(croak cluck);
use Class::DBI::Loader;
use Class::DBI;
use Config::General;
use Data::Dumper;
use Params::Validate qw(:types);
use Scalar::Util qw(reftype);

=head1 NAME

WWW::Myspace::Data - WWW::Myspace database interaction

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

This module is the database interface for the WWW::Myspace modules.  It
imports methods into the caller's namespace which allow the caller to
bypass the loader object by calling the methods directly.  This module
is intended to be used as a back end for the Myspace modules, but it can
also be called directly from a script if you need direct database
access.

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

Returns the Class::DBI::Loader object.  Handy if you want to access the
database directly.  If a loader object does not already exists, loader()
will try to create one.

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

=head2 add_account ( $account, $password )

Store your account login information in the accounts table.  The method
attempts to log in to Myspace first.  If successful, your login
information will be stored.  If your account already exists in the
accounts table, your password will be updated to the password supplied
to the method.  If successful, it returns the id of the account.  That
is, the id which has been assigned to this account in the accounts
table.  Returns 0 if there was a problem creating or updating the
account.

=cut

sub add_account {

    my $account_name = shift;
    my $password = shift;
    
    croak "no db connection" unless ( $self->loader );
    
    my $myspace = WWW::Myspace->new( $account_name, $password );
    
    unless ( $myspace->logged_in ) {
        croak "Login failed using: $account_name / $password\n";
    }
    
    my $account = $self->{'Accounts'}->find_or_create(
        { account_name => $account_name, }
    );
        
    $account->myspace_password( $password );
    $account->my_friend_id( $myspace->my_friend_id );
    my $update = $account->update;
    
    if ( $update ) {
        return $account->account_id;
    }
    else {
        return 0;
    }
    

}

=head2 update_friend( $myspace, $friend_id )

The "friends" table in your local database stores information about
myspace friends, shared among all accounts using your database.
This lets you store additional information about them, such as their
first name, and is also used by WWW::Myspace methods and modules
to track information related to friends.

update_friend takes a single friend id and makes sure it is represented
in the local "friends" table.

    my $data = new WWW::Myspace::Data( \%config );
    
    $data->update_friend( $myspace, $friend_id );
    
=cut

sub update_friend {
    
    croak "no db connection" unless ( $self->loader );

    my $friend_id = shift;
    my $myspace   = $self->{'myspace'};
    
    unless ( $self->{'account_id'} ) {
    
        my $account = $self->{'Accounts'}->retrieve( 
            my_friend_id => $myspace->my_friend_id,
        );
        
        # tweak this later to create an account automatically
        # rather than croaking
        unless ( $account ) {
            croak "this account does not exist\n";
        }
        
        $self->{'account_id'} = $account->account_id;
    }
    
    # manage profile in "friends" table
    my $friend = $self->{'Friends'}->find_or_create( 
        { friend_id => $friend_id, }
    );
        
    $friend->user_name( $myspace->friend_user_name( $friend_id ) );
    $friend->url( $myspace->friend_url( $friend_id ) );
    
    if ( $myspace->is_band( $friend_id  ) ) {
        $friend->is_band( 'Y');
    }
    
    $friend->update;
    
    # map friend to account in "friend_to_account" table
    my $account = $self->{'FriendToAccount'}->find_or_create(
        {   friend_id => $friend_id,
            account_id => $self->{'account_id'},
        }
    );
    
    unless ( $account->time ) {
        $account->time( time() );
    }
    
    $account->update;

}

=head2 update_all_friends( $myspace )

update_all_friends is really just a wrapper around update_friend  This
method fetches a complete list of your friends currently listed at
MySpace and makes sure that all myspace users that are friends
of your account are represented in the local "friends" table.  It does
not delete friends which may have been removed from your MySpace
account since your last update.

=cut

sub update_all_friends {
    
    my @friends = $self->{'myspace'}->get_friends;
    # test on 2 ids rather than fetching all friends
    #my @friends = ( '6759473', '1000070' );
    
    foreach my $friend_id ( @friends ) {
        $self->update_friend( $friend_id );
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
        dsn                     => $self->{'db'}->{'dsn'},
        user                    => $self->{'db'}->{'user'},
        password                => $self->{'db'}->{'password'},
        options                 => $options,
        namespace               => 'WWW::Myspace::Data',
        relationships           => 1,
        options                 => { AutoCommit => 1 }, 
        inflect                 => { child => 'children' }
        
        #additional_classes      => qw/Class::DBI::AbstractSearch/,
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
        croak "couldn't not make a database connection\n";
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

This module is in developer mode.  We still need to add a database
schema and integrate it with the WWW::Myspace modules.

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
