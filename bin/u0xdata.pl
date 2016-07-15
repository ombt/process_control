#!/usr/bin/perl -w
######################################################################
#
# combine FIDs, U0X and MPR files to generate a CSV file with
# combined data: FID, LANE, STAGE, OUTPUT, MACHINE, PRODUCT, TIME.
#
# 12/17/2015 - adding extra timestamp field
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
use Time::Local;
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
# files to read.
#
use constant INDEX => 'Index.csv';
use constant INFORMATION => 'Information.csv';
use constant FILENAME_TO_IDS => 'FILENAME_TO_IDS.csv';
#
# files to write.
#
use constant FID_DATA => 'FID_DATA.csv';
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
my $verbose = NOVERBOSE;
my $delimiter = "\t";
my $append_data = FALSE;
my $fid_data_path = FID_DATA();
#
my %verbose_levels =
(
    off => NOVERBOSE(),
    min => MINVERBOSE(),
    mid => MIDVERBOSE(),
    max => MAXVERBOSE()
);
#
my @required_files = ( INDEX(), INFORMATION(), FILENAME_TO_IDS() );
#
######################################################################
#
sub usage
{
    my ($arg0) = @_;
    print $log_fh <<EOF;

usage: $arg0 [-?] [-h]  \\ 
        [-w | -W |-v level] \\ 
        [-l logfile] \\ 
        [-d delimiter] \\
        [-r|-a] 

where:
    -? or -h - print this usage.
    -w - enable warning (level=min=1)
    -W - enable warning and trace (level=mid=2)
    -v - verbose level: 0=off,1=min,2=mid,3=max
    -l logfile - log file path
    -d delimiter - CSV delimiter character. default is a tab.
    -r - remove old FID_DATA CSV file (default).
    -a - append to old FID_DATA CSV file.

EOF
}
#
sub read_file
{
    my ($file, $pdata) = @_;
    #
    printf $log_fh "%d: Reading file: %s\n", __LINE__, $file;
    #
    if ( ! -r $file )
    {
        printf $log_fh "%d: ERROR: file $file is NOT readable\n\n", __LINE__;
        return FAIL;
    }
    #
    unless (open(INFD, $file))
    {
        printf $log_fh "%d: ERROR: unable to open $file.\n\n", __LINE__;
        return FAIL;
    }
    @{$pdata} = <INFD>;
    close(INFD);
    #
    # remove any CR-NL sequences from Windose.
    chomp(@{$pdata});
    s/\r//g for @{$pdata};
    #
    return SUCCESS;
}
#
sub sort_data
{
    my ($praw, $phash, $pkeys) = @_;
    #
    # remove header
    #
    shift @{$praw};
    #
    while (scalar(@{$praw}) > 0)
    {
        my @data = split /${delimiter}/, shift @{$praw};
        $phash->{$data[0]}{$data[1]} = $data[2];
    }
    #
    @{$pkeys} = sort { $a <=> $b }keys %{$phash};
    #
    return SUCCESS;
}
#
sub split_fname_data
{
    my ($praw, $phash) = @_;
    #
    # remove header
    #
    shift @{$praw};
    #
    while (scalar(@{$praw}) > 0)
    {
        my @data = split /${delimiter}/, shift @{$praw};
        $phash->{$data[1]} = $data[0];
    }
    #
    return SUCCESS;
}
#
sub dump_data
{
    my ($name, $pdata) = @_;
    #
    return unless ($verbose >= MINVERBOSE);
    #
    foreach my $key (@{$pdata})
    {
        printf $log_fh "%d: %s key: %s\n", __LINE__, $name, $key
    }
}
#
sub get_file_type
{
    my ($fname) = @_;
    #
    my $file_type = '';
    if ($fname =~ m/^.*\.u01$/i)
    {
        $file_type = 'u01';
    }
    elsif ($fname =~ m/^.*\.u03$/i)
    {
        $file_type = 'u03';
    }
    elsif ($fname =~ m/^.*\.mpr$/i)
    {
        $file_type = 'mpr';
    }
    #
    return $file_type;
}
sub date_to_tstamp
{
    my($date) = @_;
    #
    # sample date - 20150915072307189
    #
    # 2015 09 15 07 23 07 189
    # YYYY MM DD hh mm ss ms
    #
    my $YYYY = substr($date, 0, 4);
    my $MM = substr($date, 4, 2);
    my $DD = substr($date, 6, 2);
    #
    my $hh = substr($date, 8, 2);
    my $mm = substr($date, 10, 2);
    my $ss = substr($date, 12, 2);
    #
    my $ms = substr($date, 14, 3);
    #
    my $timestamp = timelocal($ss,$mm,$hh,$DD,$MM-1,$YYYY);
    #
    return($ timestamp);
}

#
sub merge_data
{
    my ($path, 
        $pfname_hash, 
        $pindex_hash, 
        $pindex_sorted_keys, 
        $pinfo_hash, 
        $pinfo_sorted_keys) = @_;
    #
    if (scalar(@{$pindex_sorted_keys}) <= 0)
    {
        printf $log_fh "%d: ERROR: INDEX keys array is empty\n", __LINE__;
        return FAIL;
    }
    elsif (scalar(@{$pinfo_sorted_keys}) <= 0)
    {
        printf $log_fh "%d: ERROR: INFORMATION keys array is empty\n", __LINE__;
        return FAIL;
    }
    #
    unlink($path) if ($append_data == FALSE);
    #
    open(my $outfh, "+>>" , $path) || die $!;
    #
    printf $outfh "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n",
                           "FID", $delimiter,
                           "FTYPE", $delimiter,
                           "DATE", $delimiter,
                           "TIMESTAMP", $delimiter,
                           "MACHINE", $delimiter,
                           "LANE", $delimiter,
                           "STAGE", $delimiter,
                           "OUTPUT", $delimiter,
                           "MJSID", $delimiter,
                           "LOTNAME", $delimiter,
                           "LOTNUMBER", $delimiter,
                           "SERIAL", $delimiter,
                           "PRODUCTID", $delimiter,
                           "PRODUCT";
    #
    my $indexkey = shift @{$pindex_sorted_keys};
    my $infokey = shift @{$pinfo_sorted_keys};
    #
    while ((scalar(@{$pindex_sorted_keys}) > 0) &&
           (scalar(@{$pinfo_sorted_keys}) > 0))
    {
        my $file_type = '';
        #
        if ($indexkey > $infokey)
        {
            $infokey = shift @{$pinfo_sorted_keys};
        }
        elsif ($indexkey < $infokey)
        {
            $indexkey = shift @{$pindex_sorted_keys};
        }
        elsif (exists($pfname_hash->{$indexkey}))
        {
            my $fname = $pfname_hash->{$indexkey};
            #
            $file_type = get_file_type($fname);
            if ($file_type eq '')
            {
                # unknown file type
                $infokey = shift @{$pinfo_sorted_keys};
                $indexkey = shift @{$pindex_sorted_keys};
                printf $log_fh "%d: Unknown file type: %s\n", __LINE__, $fname;
                next;
            }
            #
            my $fname_date = '';
            my $fname_mach_no = '';
            my $fname_stage = '';
            my $fname_lane = '';
            my $fname_pcb_serial = '';
            my $fname_pcb_id = '';
            my $fname_output_no = '';
            my $fname_pcb_id_lot_no = '';
            #
            my @parts = split('\+-\+', $fname);
            if (scalar(@parts) >= 9)
            {
                $fname_date          = $parts[0];
                $fname_mach_no       = $parts[1];
                $fname_stage         = $parts[2];
                $fname_lane          = $parts[3];
                $fname_pcb_serial    = $parts[4];
                $fname_pcb_id        = $parts[5];
                $fname_output_no     = $parts[6];
                $fname_pcb_id_lot_no = $parts[7];
            }
            else
            {
                @parts = split('-', $fname);
                if (scalar(@parts) >= 9)
                {
                    $fname_date          = $parts[0];
                    $fname_mach_no       = $parts[1];
                    $fname_stage         = $parts[2];
                    $fname_lane          = $parts[3];
                    $fname_pcb_serial    = $parts[4];
                    $fname_pcb_id        = $parts[5];
                    $fname_output_no     = $parts[6];
                    $fname_pcb_id_lot_no = $parts[7];
                }
            }
            #
            my $date      = $fname_date;
            my $mjsid   = (exists($pindex_hash->{$indexkey}{MJSID})) ? 
                               $pindex_hash->{$indexkey}{MJSID} : "UNKNOWN";
            $mjsid = "UNKNOWN" if ( ! defined($mjsid) );
            my $machine = $fname_mach_no;
            #
            my $lotnumber = (exists($pinfo_hash->{$infokey}{LotNumber})) ? 
                                 $pinfo_hash->{$infokey}{LotNumber} : -1;
            my $lotname   = (exists($pinfo_hash->{$infokey}{LotName})) ? 
                                 $pinfo_hash->{$infokey}{LotName} : "UNKNOWN";
            $lotname = "UNKNOWN" if ( ! defined($lotname) );
            my $lane      = (exists($pinfo_hash->{$infokey}{Lane})) ? 
                                 $pinfo_hash->{$infokey}{Lane} : -1;
            my $stage     = (exists($pinfo_hash->{$infokey}{Stage})) ? 
                                 $pinfo_hash->{$infokey}{Stage} : -1;
            my $output    = (exists($pinfo_hash->{$infokey}{Output})) ? 
                                 $pinfo_hash->{$infokey}{Output} : -1;
            my $productid = (exists($pinfo_hash->{$infokey}{ProductID})) ? 
                                 $pinfo_hash->{$infokey}{ProductID} : -1;
            $productid = "UNKNOWN" if ( ! defined($productid) );
            my $serial    = (exists($pinfo_hash->{$infokey}{Serial})) ? 
                                 $pinfo_hash->{$infokey}{Serial} : -1;
            #
            # strip out any double quotes
            #
            $date    =~ s|["/,:]||g;
            $mjsid   =~ s/"//g;
            $machine =~ s/"//g;
            #
            $lotnumber =~ s/"//g;
            $lotname   =~ s/"//g;
            $lane      =~ s/"//g;
            $stage     =~ s/"//g;
            $output    =~ s/"//g;
            $productid =~ s/"//g;
            $serial    =~ s/"//g;
            #
            my $timestamp = date_to_tstamp($date);
            #
            my $product = $mjsid . "_" . $lotname . "_" . $lotnumber;
            #
            printf $outfh "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n",
                           $indexkey, $delimiter,
                           $file_type, $delimiter,
                           $date, $delimiter,
                           $timestamp, $delimiter,
                           $machine, $delimiter,
                           $lane, $delimiter,
                           $stage, $delimiter,
                           $output, $delimiter,
                           $mjsid, $delimiter,
                           $lotname, $delimiter,
                           $lotnumber, $delimiter,
                           $serial, $delimiter,
                           $productid, $delimiter,
                           $product;
            #
            $infokey = shift @{$pinfo_sorted_keys};
            $indexkey = shift @{$pindex_sorted_keys};
        }
        else
        {
            #
            # no filenam name for this file id.
            #
            $infokey = shift @{$pinfo_sorted_keys};
            $indexkey = shift @{$pindex_sorted_keys};
        }
    }
    #
    if (($indexkey == $infokey) &&
        (exists($pfname_hash->{$indexkey})))
    {
        my $fname = $pfname_hash->{$indexkey};
        #
        my $file_type = get_file_type($fname);
        if ($file_type eq '')
        {
            # unknown file type
            printf $log_fh "%d: Unknown file type: %s\n", __LINE__, $fname;
        }
        else
        {
            #
            my $fname_date = '';
            my $fname_mach_no = '';
            my $fname_stage = '';
            my $fname_lane = '';
            my $fname_pcb_serial = '';
            my $fname_pcb_id = '';
            my $fname_output_no = '';
            my $fname_pcb_id_lot_no = '';
            #
            my @parts = split('\+-\+', $fname);
            if (scalar(@parts) >= 9)
            {
                $fname_date          = $parts[0];
                $fname_mach_no       = $parts[1];
                $fname_stage         = $parts[2];
                $fname_lane          = $parts[3];
                $fname_pcb_serial    = $parts[4];
                $fname_pcb_id        = $parts[5];
                $fname_output_no     = $parts[6];
                $fname_pcb_id_lot_no = $parts[7];
            }
            else
            {
                @parts = split('-', $fname);
                if (scalar(@parts) >= 9)
                {
                    $fname_date          = $parts[0];
                    $fname_mach_no       = $parts[1];
                    $fname_stage         = $parts[2];
                    $fname_lane          = $parts[3];
                    $fname_pcb_serial    = $parts[4];
                    $fname_pcb_id        = $parts[5];
                    $fname_output_no     = $parts[6];
                    $fname_pcb_id_lot_no = $parts[7];
                }
            }
            #
            my $date    = $fname_date;
            my $mjsid   = (exists($pindex_hash->{$indexkey}{MJSID})) ? 
                               $pindex_hash->{$indexkey}{MJSID} : "UNKNOWN";
            my $machine = $fname_mach_no;
            #
            my $lotnumber = (exists($pinfo_hash->{$infokey}{LotNumber})) ? 
                                 $pinfo_hash->{$infokey}{LotNumber} : -1;
            my $lotname   = (exists($pinfo_hash->{$infokey}{LotName})) ? 
                                 $pinfo_hash->{$infokey}{LotName} : "UNKNOWN";
            my $lane      = (exists($pinfo_hash->{$infokey}{Lane})) ? 
                                 $pinfo_hash->{$infokey}{Lane} : -1;
            my $stage     = (exists($pinfo_hash->{$infokey}{Stage})) ? 
                                 $pinfo_hash->{$infokey}{Stage} : -1;
            my $output    = (exists($pinfo_hash->{$infokey}{Output})) ? 
                                 $pinfo_hash->{$infokey}{Output} : -1;
            my $productid = (exists($pinfo_hash->{$infokey}{ProductID})) ? 
                                 $pinfo_hash->{$infokey}{ProductID} : -1;
            my $serial    = (exists($pinfo_hash->{$infokey}{Serial})) ? 
                                 $pinfo_hash->{$infokey}{Serial} : -1;
            #
            $mjsid = "UNKNOWN" if ( ! defined($mjsid) );
            $lotname = "UNKNOWN" if ( ! defined($lotname) );
            $productid = "UNKNOWN" if ( ! defined($productid) );
            #
            # strip out any double quotes
            #
            $date    =~ s|["/,:]||g;
            $mjsid   =~ s/"//g;
            $machine =~ s/"//g;
            #
            $lotnumber =~ s/"//g;
            $lotname   =~ s/"//g;
            $lane      =~ s/"//g;
            $stage     =~ s/"//g;
            $output    =~ s/"//g;
            $productid =~ s/"//g;
            $serial    =~ s/"//g;
            #
            my $timestamp = date_to_tstamp($date);
            #
            my $product = $mjsid . "_" . $lotname . "_" . $lotnumber;
            #
            printf $outfh "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n",
                           $indexkey, $delimiter,
                           $file_type, $delimiter,
                           $date, $delimiter,
                           $timestamp, $delimiter,
                           $machine, $delimiter,
                           $lane, $delimiter,
                           $stage, $delimiter,
                           $output, $delimiter,
                           $mjsid, $delimiter,
                           $lotname, $delimiter,
                           $lotnumber, $delimiter,
                           $serial, $delimiter,
                           $productid, $delimiter,
                           $product;
        }
    }
    #
    close($outfh);
    #
    return SUCCESS;
}
#
######################################################################
#
my %opts;
if (getopts('?hwWv:l:d:ra', \%opts) != 1)
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
    elsif ($opt eq 'r')
    {
        $append_data = FALSE;
    }
    elsif ($opt eq 'a')
    {
        $append_data = TRUE;
    }
    elsif ($opt eq 'w')
    {
        $verbose = MINVERBOSE;
    }
    elsif ($opt eq 'W')
    {
        $verbose = MIDVERBOSE;
    }
    elsif ($opt eq 'v')
    {
        if ($opts{$opt} =~ m/^[0123]$/)
        {
            $verbose = $opts{$opt};
        }
        elsif (exists($verbose_levels{$opts{$opt}}))
        {
            $verbose = $verbose_levels{$opts{$opt}};
        }
        else
        {
            printf $log_fh "\n%d: ERROR: Invalid verbose level: $opts{$opt}\n", __LINE__;
            usage($cmd);
            exit 2;
        }
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
# check if required files exist.
#
my $ok = TRUE;
#
foreach my $req_file (@required_files)
{
    if ( ! -r "$req_file")
    {
        printf $log_fh "%d: ERROR: Required file NOT found: %s\n", __LINE__, $req_file;
        $ok = FALSE;
    }
}
#
if ( $ok == FALSE )
{
   exit 2;
}
#
my @index_raw = ();
die "Unable to read file INDEX" 
    unless (read_file(INDEX(), \@index_raw) == SUCCESS);
#
my %index_hash = ();
my @index_sorted_keys = ();
die "Unable to sort file INDEX data" 
    unless (sort_data(\@index_raw, \%index_hash, \@index_sorted_keys) == SUCCESS);
dump_data("Index", \@index_sorted_keys);
#
my @info_raw = ();
die "Unable to read file INFORMATION" 
    unless (read_file(INFORMATION(), \@info_raw) == SUCCESS);
#
my %info_hash = ();
my @info_sorted_keys = ();
die "Unable to sort file INFORMATION data" 
    unless (sort_data(\@info_raw, \%info_hash, \@info_sorted_keys) == SUCCESS);
dump_data("Information", \@info_sorted_keys);
#
my @fname_raw = ();
die "Unable to read file FILENAME_TO_IDS" 
    unless (read_file(FILENAME_TO_IDS(), \@fname_raw) == SUCCESS);
#
my %fname_hash = ();
die "Unable to sort file FILENAME_TO_IDS data" 
    unless (split_fname_data(\@fname_raw, \%fname_hash) == SUCCESS);
printf $log_fh "%d: FNAME Key Count: %d\n", __LINE__, scalar(keys %fname_hash);
#foreach my $key ( sort { $a <=> $b } keys %fname_hash )
#{
    #printf $log_fh "%d: FNAME %s => ID %s\n", __LINE__, $key, $fname_hash{$key};
#}
#
die "Unable to merge data" 
    unless (merge_data($fid_data_path, 
                      \%fname_hash,
                      \%index_hash, \@index_sorted_keys, 
                      \%info_hash, \@info_sorted_keys) == SUCCESS);
#
exit 0;
