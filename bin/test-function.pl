#!/usr/bin/perl -w
#
use strict;

use constant TRUE => 1;
use constant FALSE => 0;
#
sub func_A
{
    printf "Calling func_A ... \n";
    return;
}

sub func_C
{
    printf "Calling func_C ... \n";
    return;
}

sub function_exists
{
    my ($func_name) = @_;
    if (defined(&{$func_name}))
    {
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}

foreach my $func (@ARGV)
{
    if (function_exists($func) == TRUE)
    {
        no strict 'refs';
        printf "Function %s EXISTS ...\n", $func;
        &{$func}();
    }
    else
    {
        printf "Function %s DOES NOT EXIST ...\n", $func;
    }
}

exit(0);
