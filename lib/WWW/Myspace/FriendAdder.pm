package WWW::Myspace::FriendAdder;

use Spiffy -Base;

use Carp;
use Config::General;
use Data::Dumper;
use IO::Prompt;
use List::Compare;
use Math::Round qw(nearest);
use Params::Validate qw(:all);

=head1 NAME

WWW::Myspace::FriendAdder - Interactively add friends to your Myspace account

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This module gives you a little more flexibility when adding friends to your Myspace account.  
This module is interactive, allowing you to deal with CAPTCHA requests and then restart your 
friend requests.  It is most effective when used at the command line, but you do have the option 
to suppress its reporting and interactive nature if you find it annoying.
This module is an extension of Grant Grueninger's WWW::Myspace module.

use WWW::Myspace;
use WWW::Myspace::FriendAdder;

my $myspace = new WWW::Myspace;

my $adder = WWW::Myspace::FriendAdder->new( $myspace );

my @friend_ids = ('List', 'of', 'friend', 'ids');

$adder->friend_request( @friend_ids );

By default, this  routine will try to add as many friends as possible.  When Myspace
prompts you for user input, the routine will pause and allow you as much time as you need
to fill out the Myspace form.  Once you have done so, you may prompt the script to continue
or to exit.  Upon its exit, the script will report on its success and/or failure.

=cut

# new

=pod

=head1 METHODS

=head2 new( $myspace )

Initialize and return a new WWW::Myspace::Comment object.
$myspace is a WWW::Myspace object.

Example

use WWW::Myspace;
use WWW::Myspace::FriendAdder;

my $myspace = new WWW::Myspace;

my $adder = WWW::Myspace::FriendAdder->new( $myspace );

=cut

my $default_params = { message_on_captcha   => { default => 0 }, # bypass attempt on CAPTCHA
                       interactive          => { default => 1 }, # try to be silent
                       max_attempts         => { default => 200 }, # add + captcha attempts
                       exclude_my_friends   => { default => 0 },
                       sleep                => { default => 8 },
                       random_sleep         => { default => 0 },
                       config               => 0,
                      };
field 'myspace';

sub new() {

    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    
    bless ($self, $class);
    
    if ( @_ ) { 
    
        my $myspace = shift;    
        $self->myspace( $myspace ); 
        
        # initialize parameters here
        #my %params = validate( @_, $default_params );
        
        #$self->{'_params'} = \%params;
    }
    
    
    unless ( $self->myspace ) {
        croak "No WWW::Myspace object passed to new method in WWW::Myspace::FriendAdder.pm\n";
    }
    
    return $self;
}

sub _report {
    
    if ( $self->{'params'}->{'interactive'} ) {
        print @_;
    }
}

sub return_params {

    return $self->{'params'};

}

sub set_param {

    my @params = @_;
    my %params = @_;
    my %config = ( );
    
    # base configuration comes from the file
    # individual params may override the base config
    if ( exists $params{'config'} ) {
        
        my $conf = new Config::General( $params{'config'} );
        %config = $conf->getall;
        
        foreach my $key (keys %config) {
            unless ( exists $params{$key} ) {
                $params{$key} = $config{$key};
            }
        }
        
        my @flat_params = ( );
        foreach my $key (keys %params) {
            push (@flat_params, $key, $params{$key});
        }
        
        @params = @flat_params;
        
    }    
    
    %params = validate( @params, $default_params );
    
    foreach my $key (keys %params) {
        $self->{'params'}->{$key} = $params{$key};
    }
    

}

sub get_param {

    my $param = shift;
    
    return $self->{'params'}->{$param};

}

sub friend_request {

    my @potential_friends = @_;

    my $attempts = 0; # add attempts
    my $captcha  = 0; # message_on_captcha attempts
    my $continue = 1; # break loop?
    my $count    = 1; # ids processed
    my $sleep    = $self->{'params'}->{'sleep'}; # sleep between attempts
    my %codes    = ( ); # status messages, keyed on codes
    my %code_report = ( ); # final report data, keyed on codes
    
    if ($self->{'params'}->{'exclude_my_friends'}) {
    
        my $start_time      = time();
        my @current_friends = $self->myspace->get_friends;
    
        $self->_report("Getting ids of your current friends...\n");
        # accelerated means that no sorting takes place
        my $lc = List::Compare->new( { lists => [\@current_friends, \@potential_friends], accelerated => 1, } );
        
        my @unique_ids = $lc->get_complement;

        # assemble some stats
        my $current = @current_friends;
        my $future  = @potential_friends;
        my $unique  = @unique_ids ;
        my $shared  = $future - $unique;
        my $finish_time  = time();
        my $total_time = $finish_time - $start_time;
        
        @potential_friends = @unique_ids;

        $self->_report("$total_time seconds to exclude current friends: ");
        $self->_report("$current friends now\t$future ids supplied by you\t");
        $self->_report("$unique unique ids\nYou already share $shared friends\n");
    
    }
 
    $self->_report("Beginning to process the ids...\n");
    
    foreach my $id ( @potential_friends ) {
        
        # send requests individually
        my ($status_code, $status) = $self->myspace->send_friend_request( $id );
        ++$attempts;
        
        if ( $status_code eq 'FC') {
        
            if ( $self->{'params'}->{'message_on_captcha'} ) {
        
                # You can reset the CAPTCHA just by sending a message
                # try sending a test message before reporting a problem
                my $send_to_id = 48449904;
                
                if ($self->{'params'}->{'message_on_captcha'} > 1) {
                    $send_to_id = $self->{'params'}->{'message_on_captcha'};
                }
                
                $self->myspace->send_message( $send_to_id, 'Hello', 'Just saying hi!', 0 );
                
                ($status_code, $status) = $self->myspace->send_friend_request( $id );
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
        
        push (@{$code_report{$status_code}}, $id);
        
        # build hash of status codes for final report
        $codes{$status_code} = $status;
        $self->_report( "$count)\t$id:\t$status ($status_code) " );
        
        # if there is still an FC status, it will have to be dealt with manually
        if ($status_code eq 'FC') { 
            
            # if reporting is disabled, we'll just have to exit silently here
            unless ( $self->{'params'}->{'interactive'} ) {
                last;
            }
            
            else {
            
                print "CAPTCHA response.  Please fill in the form at the following url before continuing:\n";
                print "\n\nhttp://collect.myspace.com/index.cfm?fuseaction=invite.addfriend_verify&friendID=$id\n\n";
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

        if ( $attempts >= $self->{'params'}->{'max_attempts'} ) {
            $continue = undef;
            $self->_report("\n\nMax attempts ($self->{'params'}->{'max_attempts'}) reached. Exiting nicely...\n\n");
            last;
        }

        # don't sleep if we're just going to print the report
        if ($continue) {
        
            my $sleep_now = $sleep;
            
            if ( $self->{'params'}->{'random_sleep'} ) {
                $sleep_now = nearest( .01, rand($sleep) );
            }
            
            $self->_report("\tSleeping for $sleep_now seconds...\n");
            sleep $sleep_now;
            ++$count;
        }
        
    }
    
    if ( $self->{'params'}->{'interactive'} ) {
    
        print "Final status report...\n\n######################\n";
        print "$attempts total attempts\n";
        print "$captcha 'message on captcha' attempts\n";
        
        foreach my $response_code (keys %code_report) {
        
            my $results = @{$code_report{$response_code}};
            
            print "$results $codes{$response_code} ($response_code)\n";
        
        }
        
    }

    return \%code_report;
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
Deleting message_on_captcha messages from sent mail box
Tighten up accessor/mutator functions for this module
Better randomizing of sleep time

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

1; # End of WWW::Myspace::FriendAdder
