#!perl -T

use Test::More tests => 14;
#use Test::More 'no_plan';
use strict;
use Data::Dumper;

use lib 't';
use TestConfig;
require_ok( 'WWW::Myspace::Data' );

use WWW::Myspace::Data;

my $data = WWW::Myspace::Data->new();
 
isa_ok($data, 'WWW::Myspace::Data');
can_ok( $data, 'approve_friend_requests');
can_ok( $data, 'post_comment');
can_ok( $data, 'send_message');

my $dt1 = $data->_fresh_after({ hours => 1});
isa_ok($dt1, 'DateTime');

my $dt2 = $data->_fresh_after({ hours => 2});

cmp_ok($data->_is_fresh( $dt1, $dt2 ), '==', 1, 'data is fresh');
cmp_ok($data->_is_fresh( $dt2, $dt1 ), '==', -1, 'data is not fresh');

SKIP: {
      skip 'no config file for testing', 6 unless -e 'friend_adder.cfg';

    my %params = (
        config_file => 'friend_adder.cfg',
        config_file_format => 'CFG',
    );
    
    require_ok('Config::General');
    my $conf = new Config::General("$params{'config_file'}");
    my %config = $conf->getall;
    
    my $myspace = WWW::Myspace->new( auto_login => 0 );
    
    my $data = WWW::Myspace::Data->new($myspace, { db => $config{'db'} } );
    my $loader = $data->loader;
    
    my $friend_url = 'montgomerygentry';
    my $friend_id = $myspace->friend_id( $friend_url ) || die;
    
    ok( $friend_id, "got friend_id");
    
    ok( $data->cache_friend( $friend_id ), 'friend cached');
    my $tracking = $data->track_friend( $friend_id );
    ok( $tracking->profile_views, 'got profile views');
    
    $friend_id = $myspace->friend_id('greatbigseaofficial');
    ok( $data->cache_friend( page => $myspace->current_page), "cached friend from page");
    
    $tracking = $data->track_friend( page => $myspace->current_page );
    ok( $tracking->profile_views, 'got profile views from page');

}
