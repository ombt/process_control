# constants
#
package myconstants;
#
use strict;
use warnings;
#
use base qw( Exporter );
#
our @EXPORT = qw (
    TRUE
    FALSE
    SUCCESS
    FAIL
);
#
# logical constants
#
use constant TRUE => 1;
use constant FALSE => 0;
#
use constant SUCCESS => 1;
use constant FAIL => 0;
#
# exit with success
#
1;


