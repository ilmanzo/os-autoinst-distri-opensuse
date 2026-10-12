# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: bci-tests runner for a single container image
#   This module is scheduled dynamically by bci_test, once per container
#   image, when BCI_PER_IMAGE_TESTS is set. The run_args hold the tox
#   environment, the container engine and the pytest node IDs of the image.
#   The shell environment and the tox virtualenv are the ones prepared by
#   bci_test.
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use containers::bci_utils;

sub run {
    my ($self, $args) = @_;
    die 'Test was scheduled without the required run_args argument' unless $args;
    select_serial_terminal;

    my $env = $args->{env};
    my $timeout = get_var('BCI_IMAGE_TIMEOUT', 900) * get_var('TIMEOUT_SCALE', 1);
    my $tox_out = "tox_$self->{name}.txt";
    my $node_ids = join(' ', map { "'" . s/'/'\\''/gr . "'" } @{$args->{node_ids}});

    assert_script_run('cd /root/BCI-tests');
    assert_script_run('export USE_MACVLAN_DUMMY=1 TESTINFRA_LOGGING=1');
    # tox passes the extra arguments after the test file of the environment, so node IDs would not narrow the
    # run down to one image. Run pytest directly in the virtualenv that bci_test created with tox.
    # ponytail: assumes the default tox work directory, and misses changes of the pytest options in tox.ini
    my $cmd = ".tox/$env/bin/python -m pytest -vv --pytest-container-log-level=debug " . bci_pytest_args() . " $node_ids";
    my $ret = script_run("timeout $timeout $cmd > $tox_out 2>&1", timeout => $timeout + 60);

    # The pytest summary is at the end of the log
    my $summary = script_output("grep -E '^(FAILED|ERROR) ' $tox_out; tail -n 1 $tox_out", proceed_on_failure => 1);
    record_info('pytest', $summary);
    # man timeout: If the command times out, and --preserve-status is not set, then exit with status 124.
    my $failure = $ret == 124 ? "pytest of <$env> timed out after $timeout seconds" : $ret != 0 ? "pytest of <$env> failed" : undef;
    if ($failure) {
        upload_logs($tox_out, failok => 1);
        script_run('tar zcf commands.tgz commands-*.txt');
        upload_logs('commands.tgz', failok => 1);
    }
    my $ret_xf = script_run("awk '/short test summary info/{f=1}f' $tox_out | grep XFAIL");
    record_info('Softfail', "The tests of <$env> have softfailures(XFAIL)", result => 'softfail') if ($ret_xf == 0);
    script_run('rm -f commands-*.txt commands.tgz');

    if ($args->{last_of_env}) {
        record_disk_usage($args->{engine}, "after $env");
        script_run("$args->{engine} system prune -a -f", timeout => 300);
    }
    die $failure if $failure;
}

# post_fail_hook of the parent collects the logs of the whole machine, which is not
# worth doing for each failed image. The logs of the failed run are uploaded in run().
sub post_fail_hook { }

sub post_run_hook { }

sub test_flags {
    return {fatal => 0, no_rollback => 1};
}

1;
