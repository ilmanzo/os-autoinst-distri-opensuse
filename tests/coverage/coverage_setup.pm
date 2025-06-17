# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: setup coverage tooling
# Maintainer: Andrea Manzini <andrea.manzini@suse.com>

# test data section in the YAML schedule must contain an hash
# of packages to install -> binary to instrument. For example
#
# test_data:
#   coverage_targets:
#     unzip: /usr/bin/unzip
#     nano: /usr/bin/nano

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';
use scheduler 'get_test_suite_data';

sub run {
    select_serial_terminal;
    # enable debug repos
    # on Tumbleweed does not have debuginfo in to-be-tested snapshots, except for selected package
    # (see REPO_OSS_DEBUGINFO_PACKAGES)

    my $test_data = get_test_suite_data();
    # TODO maybe not the best way, but it works

    while (my ($name, $url) = each(%{$test_data->{repositories}})) {
        assert_script_run "zypper ar -e -f $url $name";
    }

    zypper_call 'in ' . join ' ', @{$test_data->{extra_packages}};
    # these are needed only for PIN compilation
    zypper_call 'in gcc-c++ gcc14-c++ make';    # as of 2025-617 pin does not compile yet with gcc15

    # TODO create a proper pin-coverage-3.31 rpm package on OBS ?
    assert_script_run $_ for ('mkdir -p /var/coverage', 'cd /var/coverage',
        'wget https://github.com/ilmanzo/BinaryCoverage/archive/refs/heads/main.zip',
        'unzip main.zip && rm main.zip', 'cd BinaryCoverage-main',
        'export CXX=g++-14', './build.sh', 'source ./env');

    # install packages with debug info and wrap
    # targets that will be instrumented for 'coverage'
    while (my ($package, $binary_path) = each(%{$test_data->{coverage_targets}})) {
        zypper_call "in $package $package-debuginfo";
        assert_script_run "./wrap.sh -i $binary_path";
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
