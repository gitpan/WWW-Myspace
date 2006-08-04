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
                                scripts/add_friends
                              )],
    PREREQ_PM => {
        'Test::More' => 0,
#        'HTTP::Request::Form' => 0,
        'Spiffy' => 0.24,
        'YAML' => 0.39,
#        'IO::All' => 0.33, # Needed for the scripts
        'File::Spec::Functions' => 0, # Note: Forces File::Spec 0.7 or later.
        'Contextual::Return'    => 0, # For send_friend_request method
        'Class::DBI::AbstractSearch' => 0, # FriendAdder.pm
        'Config::General'       => 0, # FriendAdder.pm
        'DateTime'              => 0, # FriendAdder.pm
        'IO::Prompt'            => 0, # FriendAdder.pm 
        'List::Compare'         => 0, # FriendAdder.pm
        'Locale::SubCountry'    => 0, # FriendAdder.pm, cool_new_people
        'Math::Round'           => 0, # FriendAdder.pm
        'Params::Validate'      => 0, # FriendAdder.pm
        'Scalar::Util'          => 0, # FriendAdder.pm
        'Class::DBI'            => 0, # Data.pm
        'Class::DBI::Loader'    => 0, # Data.pm
        'DateTime::Format::MySQL'   => 0, # Data.pm
        'WWW::Mechanize'        => 0, # Myspace.pm
        'Time::Local'			=> 0, # Myspace.pm - last_login method
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WWW-Myspace-*' },
);
