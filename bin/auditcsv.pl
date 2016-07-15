#!/usr/bin/perl -w
######################################################################
#
# audit generated csv files for consistency. simple checks.
#
######################################################################
#
use strict;
#
use Carp;
use Getopt::Std;
use File::Find;
use File::Path qw(mkpath);
use File::Basename;
use File::Path 'rmtree';
use DBI;
#
######################################################################
#
# logical constants
#
use constant TRUE => 1;
use constant FALSE => 0;
#
use constant SUCCESS => 1;
use constant FAIL => 0;
#
# verbose levels
#
use constant NOVERBOSE => 0;
use constant MINVERBOSE => 1;
use constant MIDVERBOSE => 2;
use constant MAXVERBOSE => 3;
#
######################################################################
#
# globals
#
my $cmd = $0;
my $log_fh = *STDOUT;
#
# cmd line options
#
my $logfile = '';
my $delimiter = "\t";
#
######################################################################
#
# miscellaneous functions
#
sub usage
{
    my ($arg0) = @_;
    print $log_fh <<EOF;

usage: $arg0 [-?] [-h] 
        [-l logfile]
        [-d delimiter]
        CSV-file ...

where:
    -? or -h - print this usage.
    -l logfile - log file path
    -d delimiter - CSV delimiter characer. default is a tab.

EOF
}
#
######################################################################
#
sub process_file
{
    my ($csv_file) = @_;
    #
    printf $log_fh "\n%d: Processing CSV File: %s\n", __LINE__, $csv_file;
    #
    # open CSV file and column names from first row.
    #
    open(my $infh, "<" , $csv_file) || die $!;
    #
    my $header = <$infh>;
    chomp($header);
    $header =~ s/\r//g;
    $header =~ s/\./_/g;
    $header =~ s/ /_/g;
    my @col_names = split /${delimiter}/, $header;
    my $num_col_names = scalar(@col_names);
    #
    for(my $rec_no=2; (my $row = <$infh>); $rec_no += 1)
    {
        chomp($row); $row =~ s/\r//g;
        my $num_tokens = scalar(split /${delimiter}/, $row, -1);
        if ($num_tokens != $num_col_names)
        {
            printf $log_fh "%d: ERROR in CSV File (expected: %d, found: %d): %s\n", 
                   __LINE__, $csv_file, $num_col_names, $num_tokens;
        }
    }
    #
    return;
}
#
######################################################################
#
my %opts;
if (getopts('?hl:d:', \%opts) != 1)
{
    usage($cmd);
    exit 2;
}
#
foreach my $opt (%opts)
{
    if (($opt eq 'h') or ($opt eq '?'))
    {
        usage($cmd);
        exit 0;
    }
    elsif ($opt eq 'l')
    {
        local *FH;
        $logfile = $opts{$opt};
        open(FH, '>', $logfile) or die $!;
        $log_fh = *FH;
        printf $log_fh "\n%d: Log File: %s\n", __LINE__, $logfile;
    }
    elsif ($opt eq 'd')
    {
        $delimiter = $opts{$opt};
        $delimiter = "\t" if ( $delimiter =~ /^$/ );
    }
}
#
# audit each file 
#
if ( -t STDIN )
{
    #
    # getting a list of files from command line.
    #
    if (scalar(@ARGV) == 0)
    {
        printf $log_fh "%d: ERROR: No csv files given.\n", __LINE__;
        usage($cmd);
        exit 2;
    }
    #
    foreach my $csv_file (@ARGV)
    {
        process_file($csv_file);
    }
}
else
{
    printf $log_fh "%d: Reading STDIN for list of files ...\n", __LINE__;
    #
    while( defined(my $csv_file = <STDIN>) )
    {
        chomp($csv_file);
        process_file($csv_file);
    }
}
#
exit 0;
