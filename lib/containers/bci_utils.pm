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
use testapi;

our @EXPORT = qw(record_disk_usage bci_pytest_args bci_group_by_image bci_module_name);

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

=head2 bci_group_by_image

 bci_group_by_image(@node_ids);

Group the pytest node IDs, as printed by C<pytest --collect-only -q>, by the
container image they test. Return a list of C<[$image, \@node_ids]> in the order
of first appearance. The image is the parameter of the node ID without the
C<local-> prefix that pytest-container adds to images derived from the tested one.
Node IDs without a parameter are grouped under the empty image.

=cut

sub bci_group_by_image {
    my (@node_ids) = @_;
    my (@order, %groups);
    for my $id (@node_ids) {
        my ($image) = $id =~ /^[^\[]*\[(.*)\]$/;
        $image = '' unless defined $image;
        $image =~ s/^local-//;
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

1;
