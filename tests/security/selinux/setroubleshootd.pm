# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary:
#  - Install the package setroubleshoot-server, check that it installs setroubleshoot-plugins
#  - Check setroubleshootd DBus activation only via systemd service.
#  - Check if is-active shows inactive at first, then after restart shows active at first
#    but after about 15 seconds it should be no longer active again.
#  - Check setroubleshootd invoking via polkit as root, see
#    /usr/share/dbus-1/system.d/org.fedoraproject.SetroubleshootFixit.conf
# Maintainer: QE Security <none@suse.de>
# Tags: poo#174175

use base "selinuxtest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self) = shift;
    select_serial_terminal;
    # ensure selinux is in enforcing mode
    validate_script_output 'getenforce', sub { m/Enforcing/ };
    # ensure pkg installation
    zypper_call 'in setroubleshoot-server';
    assert_script_run 'rpm -q setroubleshoot-plugins';
    # ensure current test is run as root user
    validate_script_output 'id', sub { m/uid=0\(root\)/ };
    # ensure setroubleshootd cannot be run as root
    my $errmsg = 'org.freedesktop.DBus.Error.AccessDenied: Request to own name refused by policy';
    validate_script_output('setroubleshootd -d -f 2>&1', sub { m/$errmsg/ }, proceed_on_failure => 1);
    # ensure service is inactive; then after restart should be active, and inactive again after some time
    validate_script_output('systemctl is-active setroubleshootd.service', sub { m/inactive/ }, proceed_on_failure => 1);
    validate_script_output('systemctl restart setroubleshootd;systemctl is-active setroubleshootd.service;sleep 15;systemctl is-active setroubleshootd.service', sub { m/active.*inactive/s }, proceed_on_failure => 1);
}

1;
