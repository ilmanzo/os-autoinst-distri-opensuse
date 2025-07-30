# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: samba test conecting with Active Directory using adcli
# package: samba adcli samba-winbind krb5-client
#
# Maintainer: QE Security <none@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_sle);

sub run {
    # Don't run on 12-SP2. This is much easier than a conditional schedule in the yaml file.
    if (is_sle('<12-SP3')) {
        record_info("Not available", "this test run is not available for SLES version older than 12-SP3.");
        return;
    }
    # when run in FIPS mode, bail out on < 15-SP6 due to lack of proper support for crypto-policies
    # https://jira.suse.com/browse/PED-12018
    if (get_var('FIPS_ENABLED') && is_sle('<15-SP6')) {
        record_info('TEST SKIPPED', 'missing crypto-policies support for legacy AD auth');
        return;
    }
    select_serial_terminal;
    # Install packages required to run the actual test
    zypper_call('in python3-pytest');
    # gets the test script
    assert_script_run('mkdir -p /root/samba_dc && cd /root/samba_dc');
    assert_script_run 'curl -O ' . data_url('security/samba_dc/samba_dc.tar.xz && tar -xf samba_dc.tar.xz');
    assert_script_run './run_test';
}

sub post_run_hook {
    parse_extra_log('XUnit', 'results.xml');
}

sub post_fail_hook {
    parse_extra_log('XUnit', 'results.xml');
}


1;
