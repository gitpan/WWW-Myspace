# $Id: Promoter.pm 486 2007-09-22 20:05:58Z grantg $

package WWW::Myspace::Promoter;

#use Spiffy -Base;
#use WWW::Myspace::Poster -Base;
use Carp;
use File::Spec::Functions;
use warnings;
use strict;

=head1 NAME

WWW::Myspace::Promoter - Your personal promotions department

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS


=head1 METHODS

=head2 new

Initialze and return a new object. This inherits from WWW::Myspace::MyBase,
so you include your options in any way supported there.

=cut

=head2 options

=cut

const default_options => {};

const positional_parameters => [];

=head2 myspace

Sets or returns the myspace object we'll use.

=cut

field myspace;

=head1 NOTES

 Promoter notes:
 - Priorities:
     - Approve friends
     - Comment new people
     - Message new people
     - Comment uncommented existing friends
     - Add friends
 
 I like to message groups and add friends to friends lists.
 Also offer:
 - Message friends list and groups.
   - Need different message per group or friendID.
 - add friends to friends list and groups.
 
 Config file:
 account:
 password:
 subject: # Default subject (optional)
 message: # Default message (optional)
 groups:
     { groupID => { subject => 'subject',
                     message => "message", },
     } # See friendIDs below for full options.
 friendIDs:
     { friendID => { subject => 'subject',
                     message => "message",
                     send_add => 1, # Add too (leave out or set to 0 to message only)
                     add_button => 0, # Turn off add button (default is on)
                    }, # Send message
       friendID => { }, # Send add request only
       friendID => { send_message => 1 } # Send default message.
     }
 signature: # (for all messages)
 comment_new: # Comment for newly approved friends
 comment_old: # Comment for existing friends
     { plain_text => "Plain comment",
       html => "HTML comment"
     }  # Probably add this later.
     OR
     Plain string comment.
 
 
 Current limits:
 - Messages: About 360
 - Adds: Maybe 360? May be grouped with Messages
 - Comments: unknown. appears to allow comments after messages exceeded.
     May (probably) require captcha.
 
 Algorithm:
     - Load friends
         - From groups/friendID to message (300)
             - Need to store where friendID was found to select message.
             - If we find them in 2 places we either:
                 - Get fancy (you like artist A and artist B)
                 - Pick the first or last one they're in (probably this one)
         - To approve, add to "new comment" queue (max unknown)
         - To comment (all friends, exclude already commented)
         - from friend list to add (exclude our friends, people in groups on list)
     - Approve friends
     - until DONE or exceeded usage:
         - Comment new people to 50, CAPTCHA, or done
         - If 50 or CAPTCHA:
             - if we have a message to send, send a message (resets CATPCHA).
             - else, if CAPTCHA:
                 - Send a message to test account
                 - Find and delete the message in our sent folder
                 - reset comment counter
     - until DONE, exceeded usage, or adds aren't appearing on pending:
         - Add friends until 50 or CAPTCHA
         - if 50 or CAPTCHA:
             - If we have a message to send, send a message.
             - else, if CAPTCHA:
                 - Send a message to test account.
                 - Find and delete the message in our sent folder
                 - reset add counter.
     - until DONE, or exceeded usage:
         - Comment existing friends until 50 or CAPTCHA
             - If we have a message to send, send a message.
             - else, if CAPTCHA:
                 - Send a message to test account.
                 - Find and delete the message in our sent folder
                 - reset comment counter.
     - until DONE, message_count=300 or exceeded usage:
         - Send messages.

=head1 AUTHOR

Grant Grueninger, C<< <grantg at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-www-myspace at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Myspace>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 NOTES


=head1 TO DO


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Myspace::Promoter

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

Copyright 2006 Grant Grueninger, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of WWW::Myspace::Promoter
