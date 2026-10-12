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

done_testing;
