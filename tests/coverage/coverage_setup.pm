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
use version_utils 'is_sle';
use serial_terminal 'select_serial_terminal';
use scheduler 'get_test_suite_data';

sub run {
    select_serial_terminal;
    # enable debug repos
    # on Tumbleweed does not have debuginfo in to-be-tested snapshots, except for selected package

    # TODO maybe not the best way, but it works
    my $test_data = get_test_suite_data();

    if (is_sle '>=15SP4') {
        # enable debug repos
        assert_script_run q(zypper mr -e $(zypper lr | awk '/Debug/ {print $1}'));
        assert_script_run 'zypper ref';
    } else {
        while (my ($name, $url) = each(%{$test_data->{repositories}})) {
            assert_script_run "zypper ar -e -f $url $name";
        }
    }

    zypper_call '--gpg-auto-import-keys in ' . join ' ', @{$test_data->{extra_packages}};

    assert_script_run 'export PIN_ROOT=/usr/lib64/coverage-tools/pin-root';

    # install packages with debug info and wrap
    # targets that will be instrumented for 'coverage'
    while (my ($package, $binary_path) = each(%{$test_data->{coverage_targets}})) {
        zypper_call "in $package $package-debuginfo";
        assert_script_run "funkoverage wrap $binary_path";
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
