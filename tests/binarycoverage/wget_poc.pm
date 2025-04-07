# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wget test coverage POC

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';
use binarycoverage::functions_coverage;

sub run {
    select_console "root-console";

    # Install runtime dependencies
    zypper_call("in wget");
    assert_script_run("rpm -q wget");

    my $cov = binarycoverage::functions_coverage->new('/usr/bin/wget', 'wget');

    # <= 15-SP5 has problems under FIPS with new b.o.o configuration bsc#1239835
    $cov->call(\&assert_script_run, "wget -c https://build.opensuse.org -O opensuse.html") if (is_sle('>=15-SP6'));
    $cov->call(\&assert_script_run, "wget -c https://www.google.com -O google.html");
    $cov->call(\&assert_script_run, "wget -c https://github.com -O github.html");
    $cov->report;
    my @files;
    if (is_sle('<=15-SP5')) {
        @files = qw(google.html github.html);
    } else {
        @files = qw(opensuse.html google.html github.html);
    }
    for my $var (@files) {
        assert_script_run("test -f $var");
        assert_script_run("rm -f $var");
    }
}

1;
