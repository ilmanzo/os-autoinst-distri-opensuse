
package security::openjdk_utils;

use strict;
use warnings;
use version_utils qw(is_sle is_sled is_rt);

use base 'Exporter';

our @EXPORT = qw(get_java_versions);

sub get_java_versions {
    # on newer version we need legacy module for openjdk 11, but is not available
    # on SLERT/SLED, can't test openjdk 11. On 15-SP7 17 is also in legacy module
    return '21' if (is_rt || is_sled) && is_sle('>=15-SP7');
    return '11 17 21' if (is_sle '>=15-SP6');
    return '17 21' if ((is_rt || is_sled) && is_sle('>=15-SP6'));
    return '11 17';
}

1;
