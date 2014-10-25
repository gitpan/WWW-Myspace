#!perl -T

#use Test::More 'no_plan';
use Test::More tests => 3;
use strict;

use WWW::Myspace;

use lib 't';
use TestConfig;


my $note_third_party_profile =
    "This test acts on a 3rd-party profile which we do not control;  a test\n".
    "failure here does not necessarily mean that something is broken.";


# Get myspace object
my $myspace = new WWW::Myspace( auto_login => 0 );

SKIP: {

    # Network tests.
    # All tests below require network access.
    skip 'Tests require network access', 6 if ( -f 'no-network-access' );


    # :TODO: test that passing an invalid hashref in, fails


    # :TODO: test that passing search_term=0 without keywords, fails


    # Search for non-existent band by name
    my $nonexist_band_name = "nonexist90812";

    my @nonexist_band_results = $myspace->search_music( {
        search_term => 0,
        keywords => $nonexist_band_name
    });

    # Expect exactly 0 results
    if ( !is ( scalar @nonexist_band_results, 0,
               "Expect no results for band name '$nonexist_band_name'" ) ) {
        diag $note_third_party_profile;
        warn $myspace->error if $myspace->error;
    }


    # Search for an obscure band by name
    my $obscure_band_name = "MooseMoose";
    my $obscure_band_id = 290412839;

    my @obscure_band_results = $myspace->search_music( {
        search_term => 0,
        keywords => $obscure_band_name
    });

    # Expect exactly 1 result
    is ( scalar @obscure_band_results, 1,
         "Expect exactly one result for band name '$obscure_band_name'" )
        or diag $note_third_party_profile;

    # Check the friend ID also
    is ( $obscure_band_results[0], $obscure_band_id,
         "Expect correct friend ID in search results for band '$obscure_band_name'" )
        or diag $note_third_party_profile;


    # :TODO: test that multiple results pages are correctly handled
}
