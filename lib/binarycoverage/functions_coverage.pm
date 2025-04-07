# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#

package binarycoverage::functions_coverage;

use Mojo::Base -base, -signatures;
use autodie ':all';
use testapi qw{get_var assert_script_run script_output record_info data_url};
no warnings 'redefine';
use constant COVDATA_ROOT => '/var/coverage_data';

sub new ($class, $executable, $packagename) {
    my $self = $class->SUPER::new();    # Call parent constructor
    $self->{enabled} = get_var('COVERAGE', 0);
    $self->{executable} = $executable;
    $self->{packagename} = $packagename;
    $self->{datapath} = COVDATA_ROOT . '/' . $packagename;
    $self->init;
    return $self;
}

sub init($class) {
    my $self = $class;
    return unless $self->{enabled};
    # enable debug repos
    assert_script_run q(zypper mr -e $(zypper lr | awk '/Debug/ {print $1}'));
    # refresh and install debug symbols for the package we are testing
    # install also valgrind and gdb tooling
    assert_script_run 'zypper ref';
    my $dbgpackage = $self->{packagename} . "-debuginfo";
    assert_script_run "zypper -n install gdb valgrind $dbgpackage";
    # dump the executable's functions in some place
    assert_script_run "mkdir -p $self->{datapath}";
    assert_script_run qq{gdb -ex 'set pagination off' -ex 'info functions' -ex quit $self->{executable} > $self->{datapath}/all_funcs.gdb };
    # downloads helper script
    assert_script_run "curl --create-dirs -O --output-dir $self->{datapath} " . data_url('binarycoverage/calc_coverage.py');
    assert_script_run "chmod +x $self->{datapath}/calc_coverage.py";
}

# calls wrapped func with coverage instrumentation
# this is only a workaround, a proper implementation
# would need to change *_script_run testapi - to be defined
sub call($class, $wrapped_func_ref, @args) {
    my $self = $class;
    return $wrapped_func_ref->(@args) unless ($self->{enabled});
    my $cmd = "valgrind --tool=callgrind --trace-children=yes --callgrind-out-file=$self->{datapath}/callgrind.%p $args[0] 2> /dev/null";
    $args[0] = $cmd;
    return $wrapped_func_ref->(@args);
}

# TODO accept named arguments
sub report($class, $verbose = 0) {
    my $self = $class;
    return unless $self->{enabled};
    my $cmd = "$self->{datapath}/calc_coverage.py -b $self->{packagename} -d $self->{datapath}";
    $cmd = $cmd . ' -v' if $verbose;
    record_info('COVERAGE:', script_output($cmd));
}


1;
