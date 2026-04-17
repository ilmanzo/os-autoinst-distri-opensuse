# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: setup coverage tooling
# Maintainer: Andrea Manzini <andrea.manzini@suse.com>

# test_data in the YAML schedule must contain:
#   coverage_targets: hash of package_name -> binary (scalar) or [list of binaries]
#   helper_packages:  (optional) packages needed to make tests work, but NOT instrumented
#
# Example:
#   test_data:
#     helper_packages:
#       - wget
#     coverage_targets:
#       curl: /usr/bin/curl
#       net-snmp:
#         - /usr/bin/snmpget
#         - /usr/bin/snmpset

use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use version_utils qw (is_sle has_selinux);
use serial_terminal 'select_serial_terminal';
use scheduler 'get_test_suite_data';
use repo_tools 'add_qa_head_repo';

sub run {
    select_serial_terminal;
    # enable debug repos
    # on Tumbleweed does not have debuginfo in to-be-tested snapshots, except for selected package

    # TODO maybe not the best way, but it works
    my $test_data = get_test_suite_data();

    my %repositories;    # an hash of repositories to add

    if (is_sle '>=15-SP4') {
        add_qa_head_repo;
        # enable debug repos
        assert_script_run q(zypper mr -e $(zypper lr | awk '/Debug/ {print $1}'));
        my $version = get_required_var('VERSION');
        my $baseurl = 'http://download.suse.de/ibs/SUSE/Products';
        my $debug_suffix = 'x86_64/product_debug/';
        %repositories = (
            basesystem_debug => "$baseurl/SLE-Module-Basesystem/$version/$debug_suffix",
            serverapp_debug => "$baseurl/SLE-Module-Server-Applications/$version/$debug_suffix",
            legacy_debug => "$baseurl/SLE-Module-Legacy/$version/$debug_suffix",
            scripting_debug => "$baseurl/SLE-Module-Web-Scripting/$version/$debug_suffix",
        );
    } else {
        # set SELinux to permissive, as it is not supported by coverage tools
        assert_script_run 'setenforce 0' if has_selinux;
        %repositories = (
            devtools => 'http://download.opensuse.org/repositories/devel:/tools/openSUSE_Tumbleweed',
            main => 'http://download.opensuse.org/tumbleweed/repo/oss/',
            update => 'http://download.opensuse.org/update/tumbleweed/',
            debug => 'http://download.opensuse.org/debug/tumbleweed/repo/oss/');
    }
    while (my ($name, $url) = each(%repositories)) {
        assert_script_run "zypper ar -e -f $url $name";
    }

    # install coverage tools + debuginfo, and any helper packages
    my (@packages, @binaries);
    while (my ($pkg, $targets) = each(%{$test_data->{coverage_targets}})) {
        push @packages, $pkg, $pkg . '-debuginfo';
        my @pkg_bins = ref($targets) eq 'ARRAY' ? @$targets : ($targets);
        push @binaries, @pkg_bins;
    }
    for (@{$test_data->{helper_packages} // []}) {
        push @packages, $_;
    }
    push @packages, 'coverage-tools', 'elfutils';
    zypper_call '--gpg-auto-import-keys in ' . join ' ', @packages;

    # sets up the environment for coverage
    my $log_dir = '/var/coverage/data';

    assert_script_run "mkdir -m 0777 -p $log_dir";

    # all shared libraries should have execution bit set, otherwise the instrumentation will fail
    # both in /lib and /usr/lib, and in their 64-bit counterparts
    assert_script_run 'find /lib* /usr/lib* -type f -executable -exec chmod +x {} +';

    # set capabilities to run eBPF programs without root privileges
    assert_script_run 'funkoverage setup';

    # wrap the binaries that will be instrumented for 'coverage'
    assert_script_run "funkoverage install " . join ' ', @binaries;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
