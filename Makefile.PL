use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
#    (MM->can('signature_target') ? (SIGN => 1) : ()),
    NAME                => 'WWW::Myspace',
    AUTHOR              => 'Grant Grueninger <grantg@cpan.org>',
    VERSION_FROM        => 'lib/WWW/Myspace.pm',
    ABSTRACT_FROM       => 'lib/WWW/Myspace.pm',
    PL_FILES            => {},
    'EXE_FILES'         => [qw( scripts/approve_friends
                                scripts/comment_myspace
                                scripts/message_group
                              )],
    PREREQ_PM => {
        'Test::More' => 0,
#        'HTTP::Request::Form' => 0,
        'Spiffy' => 0.24,
        'YAML' => 0.39,
#        'IO::All' => 0.33, # Needed for the scripts
        'File::Spec::Functions' => 0, # Note: Forces File::Spec 0.7 or later.
        'Contextual::Return'    => 0, # For send_friend_request method
        'Locale::SubCountry'    => 1.38, # FriendAdder.pm, cool_new_people
        'WWW::Mechanize'        => 1.20, # Myspace.pm
        'Time::Local'			=> 0, # Myspace.pm - last_login method
        'Crypt::SSLeay'			=> 0.53, # WWW::Mechanize, for SSL access to myspace.com
        'Config::General'       => 0, # MyBase.pm
        'Params::Validate'      => 0, # MyBase.pm
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WWW-Myspace-*' },
);
