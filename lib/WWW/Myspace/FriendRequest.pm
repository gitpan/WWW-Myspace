package WWW::Myspace::FriendRequest;

use WWW::Myspace::MyBase -Base;

#use Carp;
#use Config::General;
#use Data::Dumper;
#use List::Compare;
#use Math::Round qw(nearest);
#use Params::Validate qw(:all);
#use WWW::Myspace::Data;
use warnings;
use strict;

=head1 NAME

WWW::Myspace::FriendRequest - Interactively add friends to your Myspace
account

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This module gives you a little more flexibility when adding friends to
your Myspace account. It is interactive and will occasionally prompt you
for input.  You'll have the most success when using it at the command
line, but you do have the option of suppressing its reporting and
interactive nature if you want to run it from a cgi script or if you
just find it annoying.  Hey, you've got your reasons, right? This module
is an extension of Grant Grueninger's handy L<WWW::Myspace> module.

    use WWW::Myspace;
    use WWW::Myspace::FriendRequest;

    my $myspace = WWW::Myspace->new();

    my $adder = WWW::Myspace::FriendRequest->new( $myspace );

    $adder->friend_ids('List', 'of', 'friend', 'ids');

    $adder->post;

By default, this  routine will try to add as many friends as possible
until it it reaches max_count, which defaults to 50, but can be set to
any number of your choosing.  See below. When Myspace prompts you for
user input, the routine will pause and allow you as much time as you
need to fill out the Myspace form.  Once you have done so, you may
prompt the script to continue or to exit. Upon its exit, the script will
report on its success and/or failure.

=head2 default_options

Returns the default options this method takes.  Used internally to
parse and verify options.  Most options come from the Poster class.

=cut

sub default_options {
    my $options = super;
    
    $options->{message_on_captcha} = { default => 0 };

    return $options;

}

=head1 CONSTRUCTOR AND STARTUP

=head2 new()

Initialize and return a new WWW::Myspace::FriendRequest object.
$myspace is a WWW::Myspace object.

Example

    use WWW::Myspace;

    use WWW::Myspace::FriendRequest;
    
    # see WWW::Myspace docs for more info on user/pass usage
    my $myspace = WWW::Myspace->new(); 

    my $adder = WWW::Myspace::FriendRequest->new( $myspace );
    
    # or pass some startup parameters
    my %startup_params = (
        exclude_my_friends  => 1, 
        max_count           => 25, 
        config_file         => '/path/to/config_file.cfg',
    );

    my $adder = WWW::Myspace::FriendRequest->new( 
        $myspace,
        \%startup_params, 
    );

    # find all of Shania Twain's friends 
    # (hey, you've got your reasons...)
    my @friend_ids = $myspace->friends_from_profile('13866406');

    # now, ask Shania's friends to be your friends
    $adder->friend_ids( @friend_ids );
    $adder->post;

Optional Parameters

=over 4

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
 
    my $adder = WWW::Myspace::FriendRequest->( 
        $myspace, 
        { config_file => '/path/to/adder_config.cfg', }, 
    );

=item * C<< config_file_format => [YAML|CFG] >>

If you have chosen to use a configuration file, you may state explicitly
which format you are using.  You may choose between YAML and
L<Config::General>.  If you choose not to pass this parameter, it will
default to L<YAML>.

=item * C<< exclude_my_friends => [0|1] >>

You can only perform a set number of friend requests per day.  I don't
know what that number is. At this point, it's more than 200,   It could
be as many as 300.  If you know, let me know. I can't tell you for sure,
so don't go crazy and try 1,000 requests in an hour. A failed request is
a wasted interaction, and there's really no point in trying to add
people who are already on your friends list.  It just makes you look
like someone who has no clue. So, if you want to get the most out of
your bandwidth and CPU, set this value to be true.  Currently this info
is not cached, so your friend ids will have to be looked up every time
you run the script.  (I'm working on an SQL-related solution right now. 
Watch for it...)  If you have a lot of friends, keep in mind that this
will mean some extra time before your script starts trying to add
friends. Default is off.

=item * C<< interactive => [0|1] >>

This module is at its most powerful when you are able to interact with
it.  If you don't feel like interacting, set this to 0.  Default is on.

=item * C<< max_count => $value >>

Set this to any positive integer and FriendRequest will stop friend
requests when it reaches this upper limit.  Default is 50.

=item * C<< profile_type => [ 'band' | 'personal' | 'all' ] >>

Set this to band if you only want to add bands.  Set it to personal if
you only want to add personal pages.  Defaults to "all" (adds any profile). 

=item * C<< random_sleep => [0|1] >>

Want your script to feel more human?  Set I<random_sleep> to 1 and
post() will take random breaks between add requests
using Perl's built-in rand() function.  The upper limit of the random
number will be set by the I<sleep> option (see below).  Default is off.

=item * C<< sleep => $value >>

Myspace's network connectivity is wonky at the best of times.  Best not
to send a request every 0.1 seconds.  Set this to any positive number
and post() will sleep for this many seconds between add
requests.  If you enable I<random_sleep> (see above), this number will
be the upper limit of the random sleep time.  Default is 10.

=back

=cut


=head2 post

This method is the main force behind this module.  It takes the list of
friend_ids and tries to add them to your friends.  This method is
really just a wrapper around $myspace->post()  It adds
interactivity and advanced reporting to the WWW::Myspace method.  You'll
get most of the info that you need printed to your terminal when you run
your script from the command line.  But, the script will also return a
hash reference which you can use to create your own reports.  The hash
is keyed on response codes returned by WWW::Myspace.  The value of each
key is a list of friend ids which returned with that status code.

    my $report = $adder->post;
    
    # when run at the command line, you may see something like this:
    
    $ perl add.pl 

    Beginning to process the ids...
    1)      9395579:        Failed, this person is already your friend.
(FF)
                            Sleeping for 4.95 seconds...
    2)      9373522:        Passed! Verification string received. (P)
                            Sleeping for 2.43 seconds...
    3)      9315640:        Failed, you already have a pending friend
request
                            for this person (FP)
                            Sleeping for 5.71 seconds...
    4)      9277516:        Passed! Verification string received. (P)
                            Sleeping for 1.78 seconds...
    5)      9269809:        Passed! Verification string received. (P) 
    
    Max attempts (5) reached. Exiting nicely...
    
    Final status report...
    
    ######################
    5 successful adds
    1 Failed, this person is already your friend. (FF)
    1 Failed, you already have a pending friend request for this person
(FP)
    3 Passed! Verification string received. (P)

    # %report may look something like this...
    my %{$report} = (
        'FF' => [
                    '9395579'
                ],
        'FP' => [
                    '9315640'
                ],
        'P' => [
                   '9373522',
                   '9277516',
                   '9269809'
                 ],
        );



=cut

=head2 send_post( $friend_id )

This is the method, called by post (which is really part of the Poster
superclass), that actually does the posting.

=cut

sub send_post {

    my ( $id ) = @_;

    # Send the friend request
    my ( $status_code, $status ) =
        $self->myspace->send_friend_request( $id );

    # If there's a db connection and the person is already
    # listed as a friend, we need to make sure they have
    # been added to the table
    if ( $self->{'data'} && $status_code eq 'FF' ) {
        $self->{'data'}->update_friend( $id );        
    }
    
    if ( ( $status_code eq 'FC' ) && $self->{'message_on_captcha'} ) {

        # Send a message
        $self->_send_captcha_message;

        # And try again
        ( $status_code, $status ) = $self->myspace->send_friend_request( $id );
    
    }

    return ( $status_code, $status );
}

sub _send_captcha_message {

    # You can reset the CAPTCHA just by sending a message
    # try sending a test message before reporting a problem
    my $send_to_id = 48449904;
    
    if ( $self->{'message_on_captcha'} > 1 ) {
        $send_to_id = $self->{'message_on_captcha'};
    }
    
    $self->myspace->send_message( 
        $send_to_id, 
        'Hello',
        'Just saying hi!', 
        0, 
    );

    $self->{'_captcha_count'}++;

    $self->_report("message_on_captcha attempt...\n");

}

sub _final_report {
    super;

    if ( $self->{_captcha_count} ) {
        print "$self-{_captcha_count} 'message on captcha' attempts\n";
    }

}

=head2 add_to_friends

Convenience method - same as post.

=cut

sub add_to_friends {

    $self->post( @_ );
    
}

=head2 send_friend_requests( @friend_ids )

Another convenience method for those used to the old module.
If passed a list of friendIDs, it passes them to the "friend_ids"
method and calls post.

=cut

sub send_friend_requests {

    if ( @_ ) {
        $self->friend_ids( @_ );
    }

    $self->post( @_ );

}

=head2 return_params( )

Useful for testing whether your params have been set as expected.

    my $param_ref = $adder->return_params();

=cut

=head1 AUTHOR

Olaf Alders, C<< <olaf at wundersolutions.com> >> inspired by the
excellent code of Grant Grueninger

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

Caching features

Blocking friend requests to ids that are already pending

Tighten up accessor/mutator functions for this module

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Myspace::FriendRequest

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


1;    # End of WWW::Myspace::FriendRequest
