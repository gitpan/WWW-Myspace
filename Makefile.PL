use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
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
        'HTTP::Request::Form' => 0,
        'Spiffy' => 0.24,
        'YAML' => 0.39,
        'IO::All' => 0.33, # Needed for the scripts
        'File::Spec::Functions' => 0, # Note: Forces File::Spec 0.7 or later.
        'IO::Prompt' => 0, # For add_friends
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WWW-Myspace-*' },
);
