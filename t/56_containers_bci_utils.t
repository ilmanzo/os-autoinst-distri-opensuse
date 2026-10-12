use strict;
use warnings;
use Test::More;
use Test::MockModule;

use testapi;
use containers::bci_utils;

my $base = 'registry.opensuse.org/opensuse/factory/totest/containers/opensuse';

subtest '[bci_group_by_image] group by image' => sub {
    my @ids = (
        "tests/test_all.py::test_os_release[tumbleweed:latest from $base/tumbleweed:latest]",
        "tests/test_all.py::test_os_release[bci/python:3.13 from $base/bci/python:3.13]",
        "tests/test_all.py::test_certificates_are_present[local-tumbleweed:latest from $base/tumbleweed:latest]",
        "tests/test_all.py::test_product[tumbleweed:latest from $base/tumbleweed:latest]",
        'tests/test_repository.py::test_no_param',
    );
    my @groups = bci_group_by_image(@ids);

    is_deeply [map { $_->[0] } @groups], ["tumbleweed:latest from $base/tumbleweed:latest", "bci/python:3.13 from $base/bci/python:3.13", ''],
      'images in order of first appearance, local- prefix merged, no parameter grouped under the empty image';
    is_deeply $groups[0][1], [@ids[0, 2, 3]], 'all node IDs of the image are kept, in order';
    is_deeply $groups[2][1], [$ids[4]], 'node ID without parameter';
    is_deeply [bci_group_by_image()], [], 'no node IDs';
};

subtest '[bci_module_name] sanitized names' => sub {
    is bci_module_name('all', "bci/python:3.13 from $base/bci/python:3.13"), 'all_bci_python_3.13', 'path and tag separators replaced, source URL dropped';
    is bci_module_name('all', ''), 'all', 'empty image gives the environment name';
    is bci_module_name('distribution', 'opensuse/pcp:6'), 'distribution_opensuse_pcp_6', 'image without source';
};

subtest '[bci_pytest_args] settings' => sub {
    my %vars;
    my $mock = Test::MockModule->new('containers::bci_utils', no_auto => 1);
    $mock->redefine(get_var => sub { return $vars{$_[0]} // $_[1] });

    is bci_pytest_args(), '-rfExX -n auto --reruns 3 --reruns-delay 10', 'defaults';
    %vars = (BCI_IMAGE_MARKER => 'registry', BCI_RERUNS => 1, BCI_RERUNS_DELAY => 2);
    is bci_pytest_args(), '-rfExX -n auto -k "registry" --reruns 1 --reruns-delay 2', 'marker and reruns from settings';
};

subtest '[bci_junit_images] summary by image' => sub {
    my $xml = <<"XML";
<?xml version="1.0" encoding="utf-8"?>
<testsuites><testsuite name="pytest" tests="5">
<testcase classname="tests.test_all" name="test_os_release[tumbleweed:latest from $base/tumbleweed:latest]" time="1.5"/>
<testcase classname="tests.test_all" name="test_lifecycle[tumbleweed:latest from $base/tumbleweed:latest]" time="0.001"><skipped type="pytest.skip" message="not for Tumbleweed">skipped</skipped></testcase>
<testcase classname="tests.test_all" name="test_certs[local-tumbleweed:latest from $base/tumbleweed:latest]" time="30"><failure message="boom">trace</failure></testcase>
<testcase classname="tests.test_all" name="test_os_release[bci/python:3.13 from $base/bci/python:3.13]" time="2"><skipped type="pytest.xfail" message="known issue">xfail</skipped></testcase>
<testcase classname="tests.test_all" name="test_product[opensuse/pcp:6 from $base/pcp:6]" time="1"/>
</testsuite></testsuites>
XML
    my @images = bci_junit_images($xml);

    is scalar(@images), 3, 'one entry per image, derived containers merged';
    is $images[0]{title}, 'tumbleweed:latest: 1 passed, 1 failed, 1 skipped', 'title with the counts';
    is $images[0]{result}, 'fail', 'a failed test fails the image';
    like $images[0]{text}, qr/^passed   test_os_release \(1.5s\)\n/, 'test function without the image';
    like $images[0]{text}, qr/^failed   test_certs \[derived container\] \(30s\)\n\s+boom$/m, 'derived container and failure message';
    unlike $images[0]{text}, qr/not for Tumbleweed/, 'no message for skipped tests';
    is $images[1]{title}, 'bci/python:3.13: 1 xfailed', 'expected failure';
    is $images[1]{result}, 'softfail', 'an expected failure is a softfail';
    is $images[2]{result}, 'ok', 'all tests passed';
    is_deeply [bci_junit_images('<testsuites/>')], [], 'no test cases';
};

done_testing;
