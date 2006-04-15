# $Id: Poster.pm 62 2006-04-03 05:20:14Z grantg $

package WWW::Myspace::Poster;

use WWW::Myspace::MyBase -Base;
use Carp;

=head1 NAME

WWW::Myspace::Poster - Base class for posting routines

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

 package WWW::Myspace::MyPostingModule;
 
 use WWW::Myspace::Poster -Base;
 
 # Define your options
 const default_options => {
    cache_file => { default => 'mycache' }, # ( VERY IMPORTANT! )
    myspace => 0, # Also kinda important
    message => 0, # Just an example
    friend_ids => 0 # Another example
 };
 
 # Add accessors if you like (usually a good idea)
 field 'myspace';
 field 'message';
 field 'friend_ids';
 
 sub post_stuff {
    foreach my $friend ( $self->friend_ids ) {
        $result = $self->myspace->do_something( $friend, $self->message )
        $self->write_log( 'friend' => $friend, 'status' => $result );
    }
 }

This is a base class for modules like Commenter and Messenger.
If you're writing a new module that needs to send something and
remember stuff about it, you'll want to look at this module. It gives
you all sorts of neat tools, like write_log and read_log to remember
what you did, and it automatically parses all your arguments right
in the new method, and can even read them from a
config file in CFG or YAML format.  All the "new" method stuff it just
inherits from WWW::Myspace::MyBase, so look there for more info.

You MUST set the cache_file default to something specific to your module.
This will be used by the cache_file method to return (and create if needed)
the default cache file for your module.  Make sure it isn't the same as
any of the other modules or you could make a mess.  Your default
filename will be placed in myspace's cache_dir, so don't specify a path.
For example Commenter uses:

 const default_options => {
    cache_filter => { default => 'commented' },
    # ...
 }

The cache_file is where write_log and read_log write and read their data.

This module itself is a base class of WWW::Myspace::MyBase, so it inherits
the "new", default_options, and a few other methods from there. Be
sure to read up on WWW::Myspace::MyBase if you're not familiar with it,
as your class will magically inherit those methods too.

If you're writing a script that uses a subclass of this module,
you can read up on the methods it provides below.

=cut

=head1 OPTIONS

The following options can be passed to the new method, or set using
accessor methods (see below).

Note that if you're writing a script using a subclass of this module,
more options may be available to the specific subclass you're
using.

 Options with sample values:
 
 friend_ids => [ 12345, 123456 ],  # Arrayref of friendIDs.
 cache_file => '/path/to/file',
 max_count => 50,  # Maximum number of successful posts before stopping
 html => 1,        # 1=display in HTML, 0=plain text.
 delay_time => 86400,  # Number of seconds to sleep on COUNTER/CAPTCHA
 noisy => 1,  # Display interactive output (1) or be quiet (0)?
 myspace => $myspace,  # A valid, logged-in myspace object.


=head1 METHODS

#----------------------------------------------------------------------
# exclusions 


=head2 friend_ids

Retreives/sets the list of friendIDs for whom we're going to
post things.

 $message->friend_ids( 12345, 12347, 123456 ); # Set the list of friends
 
 @friend_ids = $message->friend_ids; # Retreive the list of friends

Note that this method can take a list of friends OR an arrayref to a
list of friends, and it returns a list of friends, NOT an arrayref.

=cut

sub friend_ids {
    if ( @_ ) {
        if ( ref $_[0] ) {
            $self->{friend_ids} = $_[0];
        } else {
            $self->{friend_ids} = \@_;
        }
    } else {
        if ( defined ( $self->{friend_ids} ) ) {
            return @{ $self->{friend_ids} };
        } else {
            return ();
        }
    }
}


=head2 cache_file

Sets or returns the cache filename. This defaults to
$self->default_options->{cache_file}->{default} in the
myspace object's cache_dir.
If you try to call cache_file without a value and you haven't set
default_options properly, it'll get really pissed off and throw nasty
error messages all over your screen.

For convenience this method returns the value in all cases, so you
can do this:

$cache_file = $commented->cache_file( "/path/to/file" );

=cut

sub cache_file {

    if ( @_ ) {
        $self->{cache_file} = shift;
        return;
    } elsif (! defined $self->{cache_file} ) {
        # Make the cache directory if it doesn't exist
        $self->{myspace}->make_cache_dir;
        $self->{cache_file} = catfile( $self->{myspace}->cache_dir,
            $self->default_options->{cache_file}->{default} );
    }

    return $self->{cache_file};

}


#----------------------------------------------------------------------
# max_count

=head2 max_count

Sets or returns the number of comments we should post before
stopping. Default: 50.

Call max_count( 0 ) to disable counting. This is good if you
can handle CAPTCHA responses and you want to stop only when you get
a CAPTCHA request (i.e. if you're running from a CGI
script that can pass them back to a user).

=cut

field max_count => 50;

#----------------------------------------------------------------------
# html

=head2 html( [1] [0] )

Sets to display HTML-friendly output (only really useful with "noisy"
turned on also).

Call html(1) to display HTML tags (currently just "BR" tags).
Call html(0) to display plain text.

Text output (html = 0) is enabled by default.

Example

$comment->html( 1 );

=cut

field html => 0;

#----------------------------------------------------------------------
# delay_time

=head2 delay_time

Sets the number of seconds for which the post_all method will sleep
after reaching a COUNTER or CAPTCHA response. Defaults to 86400
(24 hours).

=cut

field delay_time => 86400;

#----------------------------------------------------------------------
# noisy

=head2 noisy( [1] [0] )

If set to 1, the module should output status reports for each post.
This, of course, will vary by module, and you'll probably want to
document any module-specific output in your module.

If "noisy" is off (0), run silently, unless there is an error, until
you have to stop. Then you may print a report or status.

noisy is off (0) by default.

=cut

field noisy => 0;

=head2 set_noisy

Shortcut for noisy, which you should use instead. set_noisy is here
for backwards compatibility.

=cut

sub set_noisy {

    $self->noisy( @_ );

}

=head2 myspace

Sets/retreives the myspace object with which we're logged in. You'll
probably just pass that info to the new method, but it's here if you
want to use it.

=cut

field 'myspace';

=head1 LOGGING METHODS

=head2 reset_log( [ $filter ] )

Resets the log file.  If passed a subroutine reference in $filter,
items matching filter will be left in the log - everything else will
be erased.

WWW::Myspace::Comment, for example calls reset_log with:

 $filter = sub { ( $_->{'status'} eq "PA" ) };
 $self->reset_log( $filter );

This leaves friends that we commented that have to approve comments in
the log file, but deletes all the other log entries (see
WWW::Myspace::Comment for why you'd do that).

To delete the log file completely, just do:

 $self->reset_log;

=cut

sub reset_log {

    my ( $filter ) = @_;

    unless ( defined $filter ) {
        unlink $self->cache_file or croak @!;
        $self->{log} = undef;
    } else {
        # Read in the items to save
        $self->read_log( $filter );

        # Write that to the exclusions file.
        $self->write_log('all');
    }

}


#---------------------------------------------------------------------

=head2 write_log( 'all' | $data )

If called with "all", write $self->{log} to the log file.
If called with a hash of data, append a line to the log
file.

 $self->write_log( 'all' );
 
 $self->write_log( {
    friend_id => $friend_id,
    status => $status
 }
 
If there is a "time" field in the list of log_fields (there is by default),
write_log will automatically write the current time (the value returned by
the "time" function) to the file.

=cut

sub write_log
{
    my ( $data ) = @_;

    # We track who we've posted to in a file. We need to
    # open and close it each time to make sure everyone
    # gets stored.
    if ( $data eq 'all' ) {
        # Re-write the file (called by reset_exclusions).
        # ($fh closes when it goes out of scope)
        open( my $fh, ">", $self->cache_file ) or croak @!;
        foreach my $key_value ( sort( keys( %{ $self->{log} } ) ) ) {
            $self->$print_row( $key_value, $fh );
        }
    } else {
        # Just append the current data.
        # ($fh closes when it goes out of scope)
        open( my $fh, ">>", $self->cache_file ) or croak @!;
        
        # Write the data into the log hash
        my $key_field = $self->log_fields->[0]; # i.e. "friend_id"
        my $key_value = $data->{"$key_field"}; # i.e. "12345"
        
        # Add the time if it's not there
        unless ( exists $data->{'time'} ) {
            $data->{'time'} = time;
        }
        # Store the rest of the passed data into the log hash.
        $self->{'log'}->{$key_value} = $data;
        
        # Write that row to the log file.
        $self->$print_row( $key_value, $fh );
    }

}

# print_row( $row_key, $fh );
# Print the row of data from the log hash specified by $row_key to the
# file identified by the filehandle reference $fh.

my sub print_row {

    my ( $row_key, $fh ) = @_;
    
    # Assemble the row
    my $row = "";
    foreach my $fieldname ( @{ $self->log_fields } ) {
        ( $row ) && ( $row .= ":" );
        $row .= $self->{log}->{$row_key}->{"$fieldname"};
    }
    # Print to the file
    print $fh "$row\n";


}

=head2 log_fields

Returns a reference to an array of the columnn names you use in your
log file. Defaults to friend_id, status, and time. The first field
will be used as your unique key field.

Override this method if you want to use different columns in your
log file.

=cut

const 'log_fields' => [ 'friend_id', 'status', 'time' ];



#----------------------------------------------------------------------

=head2 read_log

Read items from the log file. The first time it's invoked, it
reads the log file contents into $self->{log}, which is also
neatly maintained by write_log. This lets you call read_log
without worrying about huge performance losses, and also
makes it extendable to use SQL in the future.

For future compatibility, you should access the log only through
read_log (i.e. don't access $self->{log} directly).

 # Post something unless we've successfully posted before
 unless ( $self->read_log("$friend_id")->{'status'} =~ /^P/ ) {
    $myspace->post_something( $friend_id )
 }

 # When did we last post to $friend_id?
 $last_time = $self->read_log("$friend_id")->{'time'};
 
 if ( $last_time ) {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
        localtime($last_time);
    print "Successfully posted to $friend_id on: " .
        "$mon/$day/$year at $hour:$min:sec\n";;
 } else {
    print "I don't remember posting to $friend_id before\n";
 }

read_log can be called with an optional filter argument, which can
be the string "all", or a reference to a subroutine that will
be used to filter the returned values.  The subroutine will be
passed a hashref of fieldnames and values, by default:

 { friend_id => 12345,
   status => P,
   time => time in 'time' format
 }

This lets you do things like this:

 # Reload the cache in memory ($self->{log})
 $self->read_log( 'all' )

 # Return a list of friends that we've already posted
 my $filter = sub { if ( $_->{'status'} =~ /^P/ ) { 1 } else { 0 } }
 @posted_friends = $self->read_log( $filter );
 
 # Of course, that's just for example - you'd really do this:
 @posted_friends = $self->read_log( sub { ( $_->{'status'} =~ /^P/ ) } );

Only the last post attempt for each key (friend_id by default) is stored
in $self->{log}.  It is possible for the cache file to have more than one
in some circumstances, but only the last will be used, and if the file
is re-written, previous entries will be erased.

=cut

sub read_log {

    my $filter = "";
    ( $filter ) = @_ if ( @_ );
    
    my $status = "";
    my $id;
    my @values;

    # If we haven't read the log file yet, do it.
    unless ( ( defined $self->{log} ) && ( $filter ne 'all' ) ) {
        
        if ( -f $self->cache_file ) {
            open( LOGGED, "<", $self->cache_file ) or croak 
                "Can't read cache file: " . $self->cache_file . "\n";
        } else {
            $self->{log} = {};
            return $self->{log};
        }

        # There's a cache file, so read it
        while ( $id = <LOGGED> ) {
            chomp $id;
            ( @values ) = split( ":", $id );
    
            # Match the values to the appropriate fieldnames
            my $i = 0;
            my %data = ();
            foreach my $value ( @values ) {
                my $fieldname = $self->log_fields->["$i"];
                $data{"$fieldname"}=$value;
                $i++;
            }
            
            $self->{'log'}->{"$values[0]"} = { %data };
    
        }
        
        close LOGGED;
    }

    # If we reloaded, we're done.
    return $self->{log} if ( $filter eq 'all' );
    
    # If they passed a specific key value instead of a filter subroutine,
    # return the appropriate record if it exists.
    if ( ( $filter ) && ( ! ref $filter ) ) {
        if ( exists $self->{log}->{"$filter"} ) {
            return $self->{log}->{$filter}
        } else {
            return "";
        }
    }
    
    # Unless we've got a real filter, return.
    unless ( ref $filter ) {
        return $self->{log};
    }
    
    # Return a list of keys that matches their filter
    my @keys = ();
    foreach my $key_value ( sort( keys( %{ $self->{log} } ) ) ) {
        if ( &$filter( $self->{log}->{"$key_value"} ) ) {
            push( @keys, $key_value );
        }
    }

    return ( @keys );

}

=head2 previously_posted( $friend_id )

This convenience method returns true if there's a log entry for
a previous successful posting. A posting is considered successful
if the first letter of its status code is a P. (Usually it'll just
be "P", but Comment, for example, has a "PA" status for "Posted but requires
Approval").

 unless ( $self->previously_posted( $friend_id ) ) {
    $self->post( $friend_id );
 }

=cut

sub previously_posted {

    return ( $self->read_log( $_[0] )->{'status'} =~ /^P/ );

}
=pod

=head1 AUTHOR

Grant Grueninger, C<< <grantg at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-www-myspace at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Myspace>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 NOTES

CAPTCHA: WWW::Myspace allows 53 to 55 posts before requiring a CAPTCHA response,
then allows 3 before requiring it again. Not sure what the timeout
is on this, but running 50 a day seems to work.

Note that the main points of leaving comments are:

  - Keep ourselves in our fans memory,
  - Be "present" in as many places as possible.

We want to appear to "be everywhere". Since we
can only post to about 50 pages a day, we maximize our exposure by
checking each page we're going to post on to see if we're already there
and skipping it if we are.

=head1 TO DO

  - Add a method to set where the exclusions file is stored.

  - Provide a CGI interface so band members can
    coordinate and type in the CAPTCHA code. Interface
    would act as a relay: for each person we'd auto-post
    to, display the filled in comment form and have them
    customize it and/or fill in the captcha code. Could run
    in semi-automatic mode where it'd only display the page
    for them if it got a code request.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Myspace::Comment

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

Copyright 2005 Grant Grueninger, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of WWW::Myspace::Comment
