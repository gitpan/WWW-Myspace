use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'WWW::Myspace',
    AUTHOR              => 'Grant Grueninger <grantg@cpan.org>',
    VERSION_FROM        => 'lib/WWW/Myspace.pm',
    ABSTRACT_FROM       => 'lib/WWW/Myspace.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'HTTP::Request::Form' => 0,
        'Spiffy' => 0.24,
        'YAML' => 0.39,
        'IO::All' => 0.33,
        'File::Spec::Functions' => 0, # Note: Forces File::Spec 0.7 or later.
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WWW-Myspace-*' },
);
