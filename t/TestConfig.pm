# Handle things that each test script will have to do.

=head1 NAME

TestConfig - Set up for WWW::Myspace dist tests

=head1 SYNOPSIS

 use lib 't';
 use TestConfig;

 $CONFIG->{'acct1'}->{'myspace'}->method;

TestConfig exports a single variable (a hashref), "$CONFIG".
$CONFIG is loaded from t/config.yaml, then for "acct1" and
"acct2", a "myspace" item is added by doing this:
 $CONFIG->{'acct1'}->{'myspace'} = new WWW::Myspace(
    $CONFIG->{'acct1'}->{'username'},
    $CONFIG->{'acct1'}->{'password'} );
 $CONFIG->{'acct2'}->{'myspace'} = new WWW::Myspace(
    $CONFIG->{'acct2'}->{'username'},
    $CONFIG->{'acct2'}->{'password'} );

See config.yaml for layout and all values of $CONFIG.

=head1 AUTHOR

Grant Grueninger, grantg <at> cpan.org

=cut

package TestConfig;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( $CONFIG login_myspace );

#warn "Loading WWW::Myspace\n";
use WWW::Myspace;
use YAML;

#warn "Reading config.yaml\n";
open( CONFIG, "<", 't/config.yaml' ) or
	warn "Can't open test config file\n";

my $x = "";
my $line;
our $CONFIG;

foreach $line ( <CONFIG> ) {
	$x .= $line;
}

close CONFIG;

$CONFIG = Load( $x );

sub login_myspace {
#	warn "Logging into " . $CONFIG->{'acct1'}->{'username'} . "\n";
	$CONFIG->{'acct1'}->{'myspace'} = new WWW::Myspace( $CONFIG->{'acct1'}->{'username'},
	$CONFIG->{'acct1'}->{'password'} );
	
#	warn "Logging into " . $CONFIG->{'acct2'}->{'username'} . "\n";
	$CONFIG->{'acct2'}->{'myspace'} = new
		WWW::Myspace( $CONFIG->{'acct2'}->{'username'},
					  $CONFIG->{'acct2'}->{'password'}
					);
	if ( $CONFIG->{'acct1'}->{'myspace'}->{'logged_in'} &&
		 $CONFIG->{'acct2'}->{'myspace'}->{'logged_in'} ) {
		return 1;
	} else {
		return 0;
	}
}

1;
