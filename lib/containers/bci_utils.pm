# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper functions shared by the bci-tests runner modules
# Maintainer: QE-C team <qa-c@suse.de>

package containers::bci_utils;

use strict;
use warnings;
use Exporter 'import';
use XML::LibXML;
use testapi;

our @EXPORT = qw(record_disk_usage bci_pytest_args bci_image_of bci_group_by_image bci_module_name bci_junit_images);

=head2 record_disk_usage

 record_disk_usage($engine, $label);

Record the root filesystem and the container engine disk usage.

=cut

sub record_disk_usage {
    my ($engine, $label) = @_;
    my $out = script_output("df -h / 2>&1; echo ---; $engine system df 2>&1", proceed_on_failure => 1);
    record_info("disk: $label", $out);
}

=head2 bci_pytest_args

 bci_pytest_args();

Return the pytest arguments, common to all the bci-tests runs, built from the job settings.

=cut

sub bci_pytest_args {
    my $bci_marker = get_var('BCI_IMAGE_MARKER');
    my $cmd = '-rfExX -n auto';
    $cmd .= " -k \"$bci_marker\"" if $bci_marker;
    $cmd .= ' --reruns ' . get_var('BCI_RERUNS', 3) . ' --reruns-delay ' . get_var('BCI_RERUNS_DELAY', 10);
    return $cmd;
}

=head2 bci_image_of

 bci_image_of($test_id);

Return the container image tested by a pytest node ID, or the name of a test case
of a JUnit report. It is the parameter of the test, without the C<local-> prefix that
pytest-container adds to images derived from the tested one. Tests without a
parameter return the empty string.

=cut

sub bci_image_of {
    my ($id) = @_;
    my ($image) = $id =~ /^[^\[]*\[(.*)\]$/;
    $image //= '';
    $image =~ s/^local-//;
    return $image;
}

=head2 bci_group_by_image

 bci_group_by_image(@node_ids);

Group the pytest node IDs, as printed by C<pytest --collect-only -q>, by the
container image they test. Return a list of C<[$image, \@node_ids]> in the order
of first appearance, see L</bci_image_of>.

=cut

sub bci_group_by_image {
    my (@node_ids) = @_;
    my (@order, %groups);
    for my $id (@node_ids) {
        my $image = bci_image_of($id);
        push @order, $image unless $groups{$image};
        push @{$groups{$image}}, $id;
    }
    return map { [$_, $groups{$_}] } @order;
}

=head2 bci_module_name

 bci_module_name($env, $image);

Return a name for the openQA module testing I<$image> in the tox environment
I<$env>. It is used in file names, so only word characters and dots are kept.

=cut

sub bci_module_name {
    my ($env, $image) = @_;
    my ($name) = split(/ from /, $image, 2);
    $name //= '';
    return join('_', grep { length } map { s/[^\w.]+/_/gr } $env, $name);
}

=head2 bci_junit_images

 bci_junit_images($junit_xml);

Summarize the JUnit report of a bci-tests run by container image. Return a list of hashes, in
the order the images first appear, with the keys C<title> (image and test counts), C<text> (one
line per test case) and C<result> (C<fail> if a test failed, C<softfail> if a test is an expected
failure, otherwise C<ok>). They can be passed to C<record_info>.

=cut

sub bci_junit_images {
    my ($junit_xml) = @_;
    my (@order, %cases);
    for my $tc (XML::LibXML->load_xml(string => $junit_xml)->findnodes('//testcase')) {
        my $image = bci_image_of($tc->getAttribute('name'));
        my ($failure) = $tc->findnodes('./failure | ./error');
        my ($skipped) = $tc->findnodes('./skipped');
        my $status = 'passed';
        $status = 'failed' if $failure;
        $status = ($skipped->getAttribute('type') // '') eq 'pytest.xfail' ? 'xfailed' : 'skipped' if $skipped && !$failure;
        my $message = ($failure // $skipped) ? ($failure // $skipped)->getAttribute('message') // '' : '';
        push @order, $image unless $cases{$image};
        # The image is in the title of the step, so keep only the test function, and tell the derived containers apart
        my $name = $tc->getAttribute('name');
        my ($test) = $name =~ /^([^\[]*)/;
        $test .= ' [derived container]' if $name =~ /\[local-/;
        push @{$cases{$image}}, {name => $test, time => $tc->getAttribute('time') // 0, status => $status, message => $message};
    }

    my @images;
    for my $image (@order) {
        my %count;
        $count{$_->{status}}++ for @{$cases{$image}};
        my ($name) = split(/ from /, $image, 2);
        my @lines = map { sprintf("%-8s %s (%ss)", $_->{status}, $_->{name}, $_->{time}) . ($_->{status} =~ /^(failed|xfailed)$/ ? "\n         " . substr($_->{message}, 0, 300) : '') } @{$cases{$image}};
        push @images, {
            title => ($name || 'no image') . ': ' . join(', ', map { "$count{$_} $_" } grep { $count{$_} } qw(passed failed xfailed skipped)),
            text => join("\n", @lines),
            result => $count{failed} ? 'fail' : $count{xfailed} ? 'softfail' : 'ok',
        };
    }
    return @images;
}

1;
