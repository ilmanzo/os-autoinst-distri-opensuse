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


subtest '[test for any SLE, no RT, no SLED]' => sub {
    my $mocked_module = Test::MockModule->new('security::openjdk_utils');
    $mocked_module->redefine(
        'is_sle' => sub { return 1; },
        'is_rt' => sub { return 0; },
        'is_sled' => sub { return 0; });
    my $java_versions = get_java_versions();
    note "Java versions: $java_versions\n";
    ok($java_versions eq '11 17 21', 'check that 11 17 21 are returned by default SLE');
};

subtest '[test for any SLE, RT, no SLED]' => sub {
    my $mocked_module = Test::MockModule->new('security::openjdk_utils');
    $mocked_module->redefine(
        'is_sle' => sub { return 1; },
        'is_rt' => sub { return 1; },
        'is_sled' => sub { return 0; });
    my $java_versions = get_java_versions();
    note "Java versions: $java_versions\n";
    ok($java_versions eq '21', 'check that SLE RT should only return 21');
};

done_testing;
