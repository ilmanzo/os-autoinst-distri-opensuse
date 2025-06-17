# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: collect coverage data, create reports and exports them
# Maintainer: Andrea Manzini <andrea.manzini@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    assert_script_run 'mkdir -p /var/coverage/report';
    assert_script_run '/var/coverage/BinaryCoverage-main/coverage_analyzer.py /var/coverage/data/* --html-output /var/coverage/report > /var/coverage/report/cov-full.txt';
    foreach my $file (split("\n", script_output 'ls -1 /var/coverage/report/*')) {
        upload_logs($file);
    }
}

1;
