package WWW::Myspace::Data;

use Spiffy -Base;

use Carp;
use Class::DBI::Loader;
use Class::DBI;
use Config::General;
use Data::Dumper;
use Scalar::Util qw(reftype);

=head1 NAME

WWW::Myspace::Data - WWW::Myspace database interaction

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

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

new() creates a Class::DBI::Loader object, based on parameters which are
passed to it by a hash reference.  You can use any parameters which you
would normally pass to Class::DBI::Loader  For example, if you are using
MySQL:

    my %config = (
        dsn       => 'dbi:mysql:database_name',
        user      => 'user_name',
        password  => 'password',
        namespace => 'WWW::Myspace::Data',
    );
    
    my $data = WWW::Myspace::Data->new( \%config );
    
    # Or
    # if you are using SQLite
    
    my %config = (
        dsn       => 'dbi:SQLite:dbname=/path/to/dbfile',
        namespace => 'WWW::Myspace::Data',
    );
    
    my $data = WWW::Myspace::Data->new( \%config );


=cut

sub new() {

    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};

    bless( $self, $class );
    
    if (@_) {
    
        my $param_ref = shift;
    
        unless (reftype($param_ref) && reftype($param_ref) eq 'HASH') {
            croak 'If you wish to pass parameters to new(), you must use a hash reference: WWW::Myspace::Data->new( { foo => bar })';
        }
        
        my $loader = Class::DBI::Loader->new( %{$param_ref} );
        $self->{'loader'} = $loader;
    
        my @classes = $loader->classes;
    
        # each class is now represented in self
        foreach my $class (@classes) {
            my @namespace = split(/::/, $class);
            $self->{$namespace[-1]} = $class;
        }
    
    }
    
    #print Dumper($self);
    #exit(0);
    return $self;

}

=head2 loader()

Returns the Class::DBI::Loader object.  Handy if you want to access the
database directly.

    my $loader = $data->loader();
    
    # get a list of all your friends
    my @friend_objects = WWW::Myspace::Data::Friends->retrieve_all;


=cut


sub loader {

    return $self->{'loader'};

}

=head2 update_friends

The "friends" table in your local database stores information about
myspace friends, shared among all accounts using your database.
This lets you store additional information about them, such as their
first name, and is also used by WWW::Myspace methods and modules
to track information related to friends.

update_friends makes sure that all myspace users that are friends
of your account are represented in the local "friends" table.

    my $data = new WWW::Myspace::Data( \%config );
    
    $data->update_friends;
    
=cut

sub update_friends {

    my $myspace = shift;
    
    my @friends = $myspace->get_friends;
    foreach my $friend_id ( @friends ) {
        $self->{'Friends'}->find_or_create( { friend_id => $friend_id } );
    }

}

=head1 AUTHOR

Olaf Alders, C<< <olaf at wundersolutions.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-www-myspace at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Myspace>.
I will be notified, and then you'll automatically be notified of progress on
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

Many thanks to Grant Grueninger for giving birth to WWW::Myspace and for his help and advice in the development of this module.

=head1 COPYRIGHT & LICENSE

Copyright 2006 Olaf Alders, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;    # End of WWW::Myspace::Data
