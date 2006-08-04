#!perl -T

use Test::More tests => 5;
#use Test::More 'no_plan';
use strict;
use Data::Dumper;

use lib 't';
use TestConfig;
require_ok( 'WWW::Myspace::Data' );

use WWW::Myspace::Data;

my $data = WWW::Myspace::Data->new();
 
isa_ok($data, 'WWW::Myspace::Data');

my $dt1 = $data->_fresh_after({ hours => 1});
isa_ok($dt1, 'DateTime');

my $dt2 = $data->_fresh_after({ hours => 2});

cmp_ok($data->_is_fresh( $dt1, $dt2 ), '==', 1, 'data is fresh');
cmp_ok($data->_is_fresh( $dt2, $dt1 ), '==', -1, 'data is not fresh');
