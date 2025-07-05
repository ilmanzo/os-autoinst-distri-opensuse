use strict;
use warnings;
use Test::More;
use Test::Warnings;
use Test::MockModule;
use List::Util qw(any none);
use testapi;
use security::openjdk_utils 'get_java_versions';

subtest '[dummy]' => sub {
    my $dummy = 3 + 3;
    ok($dummy == 6, 'check that 3+3 == 6 (setup works)');
};

subtest '[default behavior]' => sub {

    my $mocked_version_utils = Test::MockModule->new('version_utils');

    $mocked_version_utils->redefine('is_sle', sub {
            return 0;
    });

    $mocked_version_utils->redefine('is_rt', sub {
            return 0;
    });

    $mocked_version_utils->redefine('is_sled', sub {
            return 0;
    });

    my $java_versions = get_java_versions();
    ok($java_versions eq '11 17', 'check that 11 and 17 are returned by default');
};


done_testing;
