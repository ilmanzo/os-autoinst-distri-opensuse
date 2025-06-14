# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wget test coverage POC

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

use testapi qw{get_var assert_script_run script_output record_info data_url};

sub run {
    select_serial_terminal;
    # - read package name and binary from yaml data
    # - install debug packages, run gdb to list functions
    # - install intel PIN
    # - download and compile tracing pintool
    # - for each binary, replace it with a script that calls pin
}


sub install_debug_info {
    # enable debug repos
    assert_script_run q(zypper mr -e $(zypper lr | awk '/Debug/ {print $1}'));
    # refresh and install debug symbols for the package we are testing
    # install also valgrind and gdb tooling
    assert_script_run 'zypper ref';
    my $dbgpackage = $self->{packagename} . "-debuginfo";
    assert_script_run "zypper -n install gdb $dbgpackage";
    # dump the executable's functions in some place
    assert_script_run "mkdir -p $self->{datapath}";
    assert_script_run qq{gdb -ex 'set pagination off' -ex 'info functions' -ex quit $self->{executable} > $self->{datapath}/all_funcs.gdb };
}
