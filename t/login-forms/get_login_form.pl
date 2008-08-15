#!/usr/bin/perl

=head1 get_login_form.pl

This script goes to the Myspace homepage and retrieves the login form.  The HTML is cleaned up and then dumped to C<STDOUT>.

The purpose of this is to produce an offline copy for use by the test suite.

Example:

    ./get_login_form.pl > `date -I`.html

=cut

use WWW::Myspace;
use strict;

my $myspace = new WWW::Myspace( { 'auto_login' => 0 } );
my $res = $myspace->get_page ( 'http://www.myspace.com/' );
my @form = $res->decoded_content =~ /(<form[^>]*>.*?<\/form>)/igs;

# :FIXME: assumes login form is always the third form on the page
print _get_clean_form($form[1]);

=head2 _get_clean_form( $form )

Takes the HTML of a form as an argument.

Returns simplified HTML of the form elements and only the essential attributes for the form to function correctly.

=cut

sub _get_clean_form
{

    my $form = shift;

    my @form_stuffs = $form =~ /(<form[^>]*>)(.*?)(<\/form>)/igs;

    # Opening tag
    my $thing = $form_stuffs[0];
    my $action = ($thing =~ /( action=(["']).*?\2)/is)[0];
    my $method = ($thing =~ /( method=(["']).*?\2)/is)[0];
    my $name   = ($thing =~ /( name=(["']).*?\2)/is)[0];
    my $id     = ($thing =~ /( id=(["']).*?\2)/is)[0];

    my $clean_form = "<form$action$method$name$id>\n";

    my @login_form_stuff = $form_stuffs[1] =~ /(<(input|label|textarea)[^>]*(\/>|>.*?<\/\2>))/igs;
    my $num_login_form_stuff = @login_form_stuff;
    for (my $i = 0 ; $i < $num_login_form_stuff; $i+=3)
    {
        $clean_form .= "<$login_form_stuff[$i+1]";

        my $thing = $login_form_stuff[$i];
        if ($login_form_stuff[$i+1] eq "input" || $login_form_stuff[$i+1] eq "textarea")
        {
            my $type  = ($thing =~ /( type=(["']).*?\2)/is)[0];
            my $name  = ($thing =~ /( name=(["']).*?\2)/is)[0];
            my $id    = ($thing =~ /( id=(["']).*?\2)/is)[0];
            my $value = ($thing =~ /( value=(["']).*?\2)/is)[0];
            $clean_form .= "$type$name$id$value ";
        } elsif ($login_form_stuff[$i+1] eq "label")
        {
            my $for  = ($thing =~ /( for=(["']).*?\2)/is)[0];
            $clean_form .= "$for "; 
        }

        $clean_form .= "$login_form_stuff[$i+2]\n";
    }

    # Closing tag
    $clean_form .= "$form_stuffs[2]\n";

    return $clean_form;

}
