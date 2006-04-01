package WWW::Myspace::FriendAdder;

use WWW::Myspace::MyBase -Base;
 
use Carp;
use Config::General;
use Data::Dumper;
use IO::Prompt;
use List::Compare;
use Math::Round qw(nearest);
use Params::Validate qw(:all);
#use Scalar::Util qw(reftype);
use WWW::Myspace::Data;

=head1 NAME

WWW::Myspace::FriendAdder - Interactively add friends to your Myspace account

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

This module gives you a little more flexibility when adding friends to your Myspace account.  
It is interactive and will occasionally prompt you for input.  You'll have the most success
when using it at the command line, but you do have the option 
of suppressing its reporting and interactive nature if you want to run it from a cgi script
or if you just find it annoying.  Hey, you've got your reasons, right?
This module is an extension of Grant Grueninger's handy WWW::Myspace module.

    use WWW::Myspace;
    use WWW::Myspace::FriendAdder;

    my $myspace = WWW::Myspace->new();

    my $adder = WWW::Myspace::FriendAdder->new( $myspace );

    my @friend_ids = ('List', 'of', 'friend', 'ids');

    $adder->send_friend_requests( @friend_ids );

By default, this  routine will try to add as many friends as possible.  When Myspace
prompts you for user input, the routine will pause and allow you as much time as you need
to fill out the Myspace form.  Once you have done so, you may prompt the script to continue
or to exit.  Upon its exit, the script will report on its success and/or failure.

=cut

my %default_params = (
    config_file         => 0,
    config_file_format  => 0,
    db                  => { default => 0 },
    exclude_my_friends  => { default => 0 },
    exclude_logged_adds => { default => 0 },
    interactive         => { default => 1 },      # try to be silent
    max_attempts        => { default => 50 },     
    message_on_captcha  => { default => 0 },   
    myspace             => 0,
    random_sleep        => { default => 0 },
    sleep               => { default => 10 },      
);

field 'myspace';

const default_options => \%default_params;

=head1 CONSTRUCTOR AND STARTUP

=head2 new()

Initialize and return a new WWW::Myspace::FriendAdder object.
$myspace is a WWW::Myspace object.

Example

    use WWW::Myspace;

    use WWW::Myspace::FriendAdder;

    my $myspace = WWW::Myspace->new(); # see WWW::Myspace docs for more info on logging in with username/pass

    my $adder = WWW::Myspace::FriendAdder->new( $myspace );
    
    # or
    # pass some startup parameters
    my %startup_params = (
        exclude_my_friends  => 1, 
        max_attempts        => 25, 
        config_file         => '/path/to/config_file.cfg',
    );
    
    my $adder = WWW::Myspace::FriendAdder->new( $myspace, \%startup_params );

    # find all of Shania Twain's friends (hey, you've got your reasons...)
    my @friend_ids = $myspace->friends_from_profile('13866406');
    
    # now, ask Shania's friends to be your friends
    $adder->send_friend_requests( @friend_ids);

Optional Parameters

=over 4


=item * C<< exclude_my_friends => [0|1] >>

You can only perform a set number of friend requests per day.  I don't know what that number is. I'm pretty sure it's more than 200, but it may be less than 250.  I can't tell you for sure, so don't go crazy and try 1,000 requests in an hour. A failed request will still count as an attempt, so don't go wasting your daily attempts.  Unless you like to waste.  In that case, go crazy.  If you want to get the most out of your attempts, set this value to be true.  Currently this info is not cached, so your friend ids will have to be looked up every time you run the script.  If you have a lot of friends, keep in mind that this will mean some extra time before your scripts starts trying to add friends.  Default is off.

=item * C<< interactive => [0|1] >>

This module is at its most powerful when you are able to interact with it.  If you don't feel like interacting, set this to 0.  Default is on.

=item * C<< max_attempts => $value >>

Set this to any positive integer and FriendAdder will stop friend requests when it reaches this upper limit.  Default is 50.

=item * C<< random_sleep => [0|1] >>

Want your script to feel more human?  Set I<random_sleep> to 1 and send_friend_requests() will take random breaks between add requests using Perl's built-in rand() function.  The upper limit of the random number will be set by the I<sleep> option (see below).  Default is off.

=item * C<< sleep => $value >>

Myspace's network connectivity is wonky at the best of times.  Best not to send a request every 0.1 seconds.  Set this to any positive number and send_friend_requests() will sleep for this many seconds between add requests.  If you enable I<random_sleep> (see above), this number will be the upper limit of the random sleep time.  Default is 10.

=back

=cut


sub _report {

    if ( $self->{'interactive'} ) {
        print @_;
    }
}

sub return_params {

    my %params = ( );
    
    foreach my $key ( keys %{ $self->default_options } ) {
        $params{$key} = $self->{$key};
    }
    
    return \%params;

}

=head2 send_friend_requests( @friend_ids )

This method is the main force behind this module.  Pass it a list of friend_ids and it will try to add them to your friends.  This method is really just a wrapper around $myspace->send_friend_requests()  It adds interactivity and advanced reporting to the WWW::Myspace method.  You'll get most of the info that you need printed to your terminal when you run your script from the command line.  But, the script will also return a hash reference which you can use to create your own reports.  The hash is keyed on response codes returned by WWW::Myspace.  The value of each key is a list of friend ids which returned with that status code.  

    my $report = $adder->send_friend_requests( @friend_ids );
    
    # when run at the command line, you may see something like this:
    
    $ perl add.pl 

    Beginning to process the ids...
    1)      9395579:        Failed, this person is already your friend. (FF)       Sleeping for 4.95 seconds...
    2)      9373522:        Passed! Verification string received. (P)       Sleeping for 2.43 seconds...
    3)      9315640:        Failed, you already have a pending friend request for this person (FP)  Sleeping for 5.71 seconds...
    4)      9277516:        Passed! Verification string received. (P)       Sleeping for 1.78 seconds...
    5)      9269809:        Passed! Verification string received. (P) 
    
    Max attempts (5) reached. Exiting nicely...
    
    Final status report...
    
    ######################
    5 total attempts
    1 Failed, this person is already your friend. (FF)
    1 Failed, you already have a pending friend request for this person (FP)
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

sub send_friend_requests {

    my @potential_friends = @_;

    my $attempts = 0;                              # add attempts
    my $captcha  = 0;                              # message_on_captcha attempts
    my $continue = 1;                              # break loop?
    my $count    = 1;                              # ids processed
    my $sleep    = $self->{'sleep'};   # sleep between attempts
    my %codes       = ();    # status messages, keyed on codes
    my %code_report = ();    # final report data, keyed on codes
    
    # experimental database support
    if ( $self->{'db'} ) {
        WWW::Myspace::Data->new( $self->{'db'} );
    }

    if ( $self->{'exclude_my_friends'} ) {

        my $start_time      = time();
        my @current_friends = ( );
        
        # if we have database access, use our own friends list
        if ( $self->{'db'} ) {
        
            $self->_report("Getting ids of your current friends from database...\n");
            my $it = WWW::Myspace::Data::Friends->retrieve_all();
            while (my $friend = $it->next) {
                push (@current_friends, $friend->friend_id);
            }
        }
        else {
            $self->_report("Getting ids of your current friends from Myspace...\n");
            @current_friends = $self->myspace->get_friends;
        }
        
        $self->_report( "Have your friends list.  Now tossing out matches...\n");
        
        # accelerated means that no sorting takes place
        my $lc = List::Compare->new(
            {
                lists       => [ \@current_friends, \@potential_friends ],
                accelerated => 1,
            }
        );

        my @unique_ids = $lc->get_complement;
        
        if ( $self->{'db'} && $self->{'exclude_logged_adds'} ) {
            
            my @unlogged_ids = ( );
            
            foreach my $unique_id (@unique_ids) {
                my $logged = WWW::Myspace::Data::AddLog->retrieve( friend_id => $unique_id );
                
                unless ( $logged ) {
                    push (@unlogged_ids, $unique_id);
                }
            }
            
            my $before = @unique_ids;
            my $after = @unlogged_ids;
            
            #print "$before records before checking logs.  $after ids remaining.\n";
            @unique_ids = @unlogged_ids;
        }
        
        # assemble some stats
        my $current     = @current_friends;
        my $future      = @potential_friends;
        my $unique      = @unique_ids;
        my $shared      = $future - $unique;
        my $finish_time = time();
        my $total_time  = $finish_time - $start_time;

        @potential_friends = @unique_ids;

        $self->_report("$total_time seconds to exclude current friends: ");
        $self->_report("$current friends now\t$future ids supplied by you\t");
        $self->_report(
            "$unique unique ids\nYou already share $shared friends\n");

    }

    $self->_report("Beginning to process the ids...\n");

    foreach my $id (@potential_friends) {

        # send requests individually
        my ( $status_code, $status ) = $self->myspace->send_friend_request($id);
        ++$attempts;

        if ( $status_code eq 'FC' ) {

            if ( $self->{'message_on_captcha'} ) {

                # You can reset the CAPTCHA just by sending a message
                # try sending a test message before reporting a problem
                my $send_to_id = 48449904;

                if ( $self->{'message_on_captcha'} > 1 ) {
                    $send_to_id = $self->{'message_on_captcha'};
                }

                $self->myspace->send_message( $send_to_id, 'Hello',
                    'Just saying hi!', 0 );

                ( $status_code, $status ) =
                  $self->myspace->add_to_friends($id);
                ++$attempts;
                ++$captcha;

                $self->_report("message_on_captcha attempt...\n");

            }

            else {
                $continue = undef;
                $self->_report("Exiting nicely...");
                last;
            }

        }

        push ( @{ $code_report{$status_code} }, $id );

        # build hash of status codes for final report
        $codes{$status_code} = $status;
        $self->_report("$count)\t$id:\t$status ($status_code) ");
        
        if ( $self->{'db'} ) {
            
            #my $friend_obj = WWW::Myspace::Data::AddLog->insert({ friend_id => $id, result_code => $status_code,  time => time(), });
            # friend_id is keyed as unique
            my $friend_obj = WWW::Myspace::Data::AddLog->find_or_create({ friend_id => $id });
            
            $friend_obj->result_code( $status_code );
            $friend_obj->time( time() );
            $friend_obj->update;
            
            $self->_report( "added to log ");
        }
        
        # if there is still an FC status, it will have to be dealt with manually
        if ( $status_code eq 'FC' ) {

            # if reporting is disabled, we'll just have to exit silently here
            unless ( $self->{'interactive'} ) {
                last;
            }

            else {

                print
"CAPTCHA response.  Please fill in the form at the following url before continuing:\n";
                print
"\n\nhttp://collect.myspace.com/index.cfm?fuseaction=invite.addfriend_verify&friendID=$id\n\n";
                $continue = prompt "Continue? (y/n) ", -onechar, -yn;

                if ($continue) {
                    print "Continuing...\n";
                }
                else {
                    print "Exiting nicely.  Wait for the report...\n";
                    last;
                }
            }
        }

        if ( $attempts >= $self->{'max_attempts'} ) {
            $continue = undef;
            $self->_report(
"\n\nMax attempts ($self->{'max_attempts'}) reached. Exiting nicely...\n\n"
            );
            last;
        }

        # don't sleep if we're just going to print the report
        if ($continue) {

            my $sleep_now = $sleep;

            if ( $self->{'random_sleep'} ) {
                $sleep_now = nearest( .01, rand($sleep) );
            }

            $self->_report("\tSleeping for $sleep_now seconds...\n");
            sleep $sleep_now;
            ++$count;
        }

    }

    if ( $self->{'interactive'} ) {

        print "Final status report...\n\n######################\n";
        print "$attempts total attempts\n";
        
        if ($captcha) {
            print "$captcha 'message on captcha' attempts\n";
        }

        foreach my $response_code ( keys %code_report ) {

            my $results = @{ $code_report{$response_code} };

            print "$results $codes{$response_code} ($response_code)\n";

        }

    }

    return \%code_report;
}

=head2 add_to_friends( @friend_ids)

Convenience method - same as send_friend_requests.

=cut

sub add_to_friends {
    $self->send_friend_requests( @_ );
}

=head1 AUTHOR

Olaf Alders, C<< <olaf at wundersolutions.com> >> inspired by the excellent code of Grant Grueninger

=head1 BUGS

Please report any bugs or feature requests to
C<bug-www-myspace at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Myspace>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 NOTES

This module is still in its infancy.  It does a lot of cool stuff, but the interface is still
subject to change.  Please keep this in mind when upgrading

=head1 TO DO

Caching features

Blocking friend requests to ids that are already pending

Tighten up accessor/mutator functions for this module

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Myspace::FriendAdder

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


# =item * C<< config_file => $value >>
# 
# If you prefer to keep your startup parameters in a file, pass a valid filename to new.
# 
# Your startup file may contain any of the parameters that can be passed to new() (except the $myspace object).  Your config file will be used to set the default parameters for startup.  Any other parameters which you also pass to new() will override the corresponding values in the config file.  So, if you have a default setting for exclude_my_friends in your config file but also pass exclude_my_friends directly to new(), the config file value will be overriden.  The default behaviour is not to look for a config file.
# 
#     my $adder = WWW::Myspace::FriendAdder->( $myspace, { config_file => '/path/to/adder_config.cfg', } );


1;    # End of WWW::Myspace::FriendAdder
