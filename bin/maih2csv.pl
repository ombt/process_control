#!/usr/bin/perl -w
######################################################################
#
# process a maihime file and store the data in CSV files.
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
# required section names
#
use constant INDEX => '[Index]';
use constant INFORMATION => '[Information]';
#
# verbose levels
#
use constant NOVERBOSE => 0;
use constant MINVERBOSE => 1;
use constant MIDVERBOSE => 2;
use constant MAXVERBOSE => 3;
#
# section types
#
use constant SECTION_UNKNOWN => 0;
use constant SECTION_NAME_VALUE => 1;
use constant SECTION_LIST => 2;
#
# how to combine data
#
use constant COMBINE_NONE => 0;
use constant COMBINE_BY_FILENAME => 1;
use constant COMBINE_BY_FILENAME_ID => 2;
#
# filename to id constants
#
use constant MAX_RECORDS_BEFORE_WRITE => 100;
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
my $rmv_csv_dir = FALSE;
my $delimiter = "\t";
my $combine_data = COMBINE_NONE;
my $filter_sections = FALSE;
my $combine_lot_files = FALSE;
#
my $csv_base_path = undef;
$csv_base_path = $ENV{'OMBT_CSV_BASE_PATH'} 
    if (exists($ENV{'OMBT_CSV_BASE_PATH'}));
$csv_base_path = "." 
    unless (defined($csv_base_path) and ($csv_base_path ne ""));
#
my $csv_rel_path = undef;
$csv_rel_path = $ENV{'OMBT_CSV_REL_PATH'} 
    if (exists($ENV{'OMBT_CSV_REL_PATH'}));
$csv_rel_path = "CSV" 
    unless (defined($csv_rel_path) and ($csv_rel_path ne ""));
#
my $csv_path = $csv_base_path . '/' . $csv_rel_path;
#
my %verbose_levels =
(
    off => NOVERBOSE(),
    min => MINVERBOSE(),
    mid => MIDVERBOSE(),
    max => MAXVERBOSE()
);
#
my %fname_ids = 
(
    initialized => FALSE,
    fname_to_ids_path => '',
    last_fid => -1,
    fname_to_fid => {
        UNKNOWN => -1
    }
);
my %last_fname_ids = ();
#
#
my %sections = ();
#
######################################################################
#
# miscellaneous functions
#
sub usage
{
    my ($arg0) = @_;
    print $log_fh <<EOF;

usage: $arg0 [-?] [-h]  \\ 
        [-w | -W |-v level] \\ 
        [-l logfile] \\ 
        [-B base path] \\
        [-R relative path] \\
        [-P path] \\
        [-S section[,section...] \\
        [-s section[,section...] \\
        [-d delimiter] \\
        [-r] [-C|-c] [-L] \\
        maihime-file ...

where:
    -? or -h - print this usage.
    -w - enable warning (level=min=1)
    -W - enable warning and trace (level=mid=2)
    -v - verbose level: 0=off,1=min,2=mid,3=max
    -l logfile - log file path
    -B path - base csv path, defaults to '${csv_base_path}'
              or use environment variable OMBT_CSV_BASE_PATH.
    -R path - relative csv path, defaults to '${csv_rel_path}'
              or use environment variable OMBT_CSV_REL_PATH.
    -P path - csv path, defaults to '${csv_path}'
    -S section[,section...] - list of sections to process. the
                              default is to process all sections.
    -s section[,section...] - list of sections to process in addition
                              to [Index] and [Information]. the
                              default is to process all sections.
    -d delimiter - CSV delimiter character. default is a tab.
    -r - remove old CSV directory (off by default).
    -C - combine data from separate files into one file per section
         using the file name as a product to correlate related
         data. the default is to create a directory with the file name
         and write each section in a separate file.
    -c - combine data from separate files into one file per section
         using the file name to generate a unique id as a product 
         to correlate related data. the mapping of filename to id is
         stored in a separate file. the default is to create a 
         directory with the file name and write each section in 
         a separate file.
    -L - combine separate LOT files into one file keyed by LOT. 
         default is off.

EOF
}
#
######################################################################
#
# load name-value or list section
#
sub load_name_value
{
    my ($praw_data, $section, $pirec, $max_rec, $pprod_db) = @_;
    #
    $pprod_db->{found_data}->{$section} = FALSE;
    $pprod_db->{section_type}->{$section} = SECTION_NAME_VALUE;
    #
    my $re_section = '\\' . $section;
    my @section_data = 
        grep /^${re_section}\s*$/ .. /^\s*$/, @{$praw_data};
    #
    printf $log_fh "%d: <%s>\n", 
        __LINE__, 
        join("\n", @section_data) 
        if ($verbose >= MAXVERBOSE);
    #
    $$pirec += scalar(@section_data);
    #
    if (scalar(@section_data) <= 2)
    {
        $pprod_db->{$section} = {};
        printf $log_fh "\t\t%d: NO NAME-VALUE DATA FOUND IN SECTION %s. Lines read: %d\n", 
            __LINE__, $section, scalar(@section_data);
        return FAIL;
    }
    #
    shift @section_data; # remove section name
    pop @section_data;   # remove end-of-section null-length line
    #
    %{$pprod_db->{$section}->{data}} = 
        map { split /\s*=\s*/, $_, 2 } @section_data;
    #
    # remove any double quotes.
    for my $key (keys %{$pprod_db->{$section}->{data}})
    {
        $pprod_db->{$section}->{data}->{$key} =~ s/^\s*"([^"]*)"\s*$/$1/;
    }
    #
    $pprod_db->{found_data}->{$section} = TRUE;
    #
    printf $log_fh "\t\t%d: Number of key-value pairs: %d\n", 
        __LINE__, 
        scalar(keys %{$pprod_db->{$section}->{data}})
        if ($verbose >= MINVERBOSE);
    printf $log_fh "\t\t%d: Lines read: %d\n", 
        __LINE__, 
        scalar(@section_data)
        if ($verbose >= MINVERBOSE);
    #
    return SUCCESS;
}
#
sub split_quoted_string
{
    my $rec = shift;
    my $separator = shift;
    #
    my $rec_len = length($rec);
    #
    my $istart = -1;
    my $iend = -1;
    my $in_string = 0;
    #
    my @tokens = ();
    my $token = "";
    #
    for (my $i=0; $i<$rec_len; $i++)
    {
        my $c = substr($rec, $i, 1);
        #
        if ($in_string == 1)
        {
            if ($c eq '"')
            {
                $in_string = 0;
            }
            else
            {
                $token .= $c;
            }
        }
        elsif ($c eq '"')
        {
            $in_string = 1;
        }
        elsif ($c eq $separator)
        {
            # printf $log_fh "Token ... <%s>\n", $token;
            push (@tokens, $token);
            $token = '';
        }
        else
        {
            $token .= $c;
        }
    }
    #
    if (length($token) > 0)
    {
        # printf $log_fh "Token ... <%s>\n", $token;
        push (@tokens, $token);
        $token = '';
    }
    else
    {
        # null-length string
        $token = '';
        push (@tokens, $token);
    }
    #
    # printf $log_fh "Tokens: \n%s\n", join("\n",@tokens);
    #
    return @tokens;
}
#
sub load_list
{
    my ($praw_data, $section, $pirec, $max_rec, $pprod_db) = @_;
    #
    $pprod_db->{found_data}->{$section} = FALSE;
    $pprod_db->{section_type}->{$section} = SECTION_LIST;
    #
    my $re_section = '\\' . $section;
    my @section_data = 
        grep /^${re_section}\s*$/ .. /^\s*$/, @{$praw_data};
    #
    printf $log_fh "%d: <%s>\n", __LINE__, join("\n", @section_data) if ($verbose >= MAXVERBOSE);
    #
    $$pirec += scalar(@section_data);
    #
    if (scalar(@section_data) <= 3)
    {
        $pprod_db->{$section} = {};
        printf $log_fh "\t\t\t%d: NO LIST DATA FOUND IN SECTION %s. Lines read: %d\n", 
            __LINE__, 
            $section, scalar(@section_data)
            if ($verbose >= MINVERBOSE);
        return SUCCESS;
    }
    #
    shift @section_data; # remove section name
    pop @section_data;   # remove end-of-section null-length line
    #
    $pprod_db->{$section}->{header} = shift @section_data;
    @{$pprod_db->{$section}->{column_names}} = 
        split / /, $pprod_db->{$section}->{header};
    my $number_columns = scalar(@{$pprod_db->{$section}->{column_names}});
    #
    @{$pprod_db->{$section}->{data}} = ();
    #
    printf $log_fh "\t\t\t%d: Number of Columns: %d\n", 
        __LINE__, 
        $number_columns
        if ($verbose >= MINVERBOSE);
    #
    foreach my $record (@section_data)
    {
        #
        # sanity check since MAI or CRB file may be corrupted.
        #
        last if (($record =~ m/^\[[^\]]*\]/) ||
                 ($record =~ m/^\s*$/));
        #
        my @tokens = split_quoted_string($record, ' ');
        my $number_tokens = scalar(@tokens);
        #
        printf $log_fh "\t\t\t%d: Number of tokens in record: %d\n", __LINE__, $number_tokens if ($verbose >= MAXVERBOSE);
        #
        if ($number_tokens == $number_columns)
        {
            my %data = ();
            @data{@{$pprod_db->{$section}->{column_names}}} = @tokens;
            #
            unshift @{$pprod_db->{$section}->{data}}, \%data;
            printf $log_fh "\t\t\t%d: Current Number of Records: %d\n", __LINE__, scalar(@{$pprod_db->{$section}->{data}}) if ($verbose >= MAXVERBOSE);
        }
        else
        {
            printf $log_fh "\t\t\t%d: ERROR: Section: %s, SKIPPING RECORD - NUMBER TOKENS (%d) != NUMBER COLUMNS (%d)\n", __LINE__, $section, $number_tokens, $number_columns;
        }
    }
    #
    $pprod_db->{found_data}->{$section} = TRUE;
    #
    return SUCCESS;
}
#
######################################################################
#
# load and process product files, either CRB or MAI
#
sub read_file
{
    my ($prod_file, $praw_data) = @_;
    #
    printf $log_fh "\t%d: Reading Product file: %s\n", 
                   __LINE__, $prod_file;
    #
    if ( ! -r $prod_file )
    {
        printf $log_fh "\t%d: ERROR: file $prod_file is NOT readable\n\n", __LINE__;
        return FAIL;
    }
    #
    unless (open(INFD, $prod_file))
    {
        printf $log_fh "\t%d: ERROR: unable to open $prod_file.\n\n", __LINE__;
        return FAIL;
    }
    @{$praw_data} = <INFD>;
    close(INFD);
    #
    # remove any CR-NL sequences from Windose.
    chomp(@{$praw_data});
    s/\r//g for @{$praw_data};
    #
    printf $log_fh "\t\t%d: Lines read: %d\n", __LINE__, scalar(@{$praw_data}) if ($verbose >= MINVERBOSE);
    #
    return SUCCESS;
}
#
sub read_filename_id
{
    my ($prod_csv_dir) = @_;
    #
    %fname_ids = 
    (
        initialized => FALSE,
        fname_to_ids_path => '',
        last_fid => -1,
        fname_to_fid => {
            UNKNOWN => -1
        }
    );
    #
    %last_fname_ids = ();
    #
    my $fname_to_ids_path = $prod_csv_dir . "/FILENAME_TO_IDS.csv";
    #
    printf $log_fh "\t%d: Reading FILENAME_TO_IDS file: %s\n", 
                   __LINE__, $fname_to_ids_path;
    #
    $fname_ids{fname_to_ids_path} = $fname_to_ids_path;
    if ( ! -r $fname_to_ids_path )
    {
        # all done
        $fname_ids{initialized} = TRUE;
        return SUCCESS;
    }
    #
    # read in file and parse
    #
    my @raw_data = ();
    return FAIL unless (read_file($fname_to_ids_path, 
                                   \@raw_data) == TRUE);
    #
    # remove header record
    #
    my $header = shift @raw_data;
    my @column_names = split /${delimiter}/, ${header};
    my $number_columns = scalar(@{column_names});
    #
    my $last_fid = -1;
    #
    foreach my $record (@raw_data)
    {
        my @tokens = split_quoted_string($record, $delimiter);
        my $number_tokens = scalar(@tokens);
        #
        if ($number_tokens == $number_columns)
        {
            my %data = ();
            @data{@{column_names}} = @tokens;
            $fname_ids{fname_to_fid}{$data{FNAME}} = $data{FID};
            if ($data{FID} > $last_fid)
            {
                $last_fid = $data{FID};
            }
        }
    }
    #
    $fname_ids{last_fid} = $last_fid;
    $fname_ids{initialized} = TRUE;
    #
    return SUCCESS;
}
#
sub write_filename_id
{
    my $outnm = $fname_ids{fname_to_ids_path};
    printf $log_fh "\t%d: Writing FILENAME_TO_IDS file: %s\n", 
                   __LINE__, $outnm;
    #
    my $outfh = undef;
    if ( -r $outnm )
    {
        printf $log_fh "\t%d: Appending to FILENAME_TO_IDS file: %s\n", 
                       __LINE__, $outnm;
        open($outfh, ">>" , $outnm) || die $!;
    }
    else
    {
        printf $log_fh "\t%d: Writing FILENAME_TO_IDS file: %s\n", 
                       __LINE__, $outnm;
        open($outfh, ">" , $outnm) || die $!;
        printf $outfh "FNAME%sFID\n", $delimiter;
    }
    #
    my @last_keys = keys %last_fname_ids;
    printf $log_fh "\t%d: Writing %d keys to FILENAME_TO_IDS file: %s\n", 
                       __LINE__, scalar(@last_keys), $outnm;
    #
    foreach my $key (@last_keys)
    {
        printf $outfh "%s%s%s\n", 
            $key, 
            $delimiter,
            $last_fname_ids{$key};
    }
    #
    # clear out all old data
    #
    %last_fname_ids = ();
    #
    close($outfh);
}
#
sub get_filename_id
{
    my ($filename) = @_;
    #
    die "FILENAME_TO_FIDS NOT INITIALIZED." 
        unless ($fname_ids{initialized} == TRUE);
    #
    if ( ! exists($fname_ids{fname_to_fid}{$filename}))
    {
        $fname_ids{last_fid} += 1;
        $fname_ids{fname_to_fid}{$filename} = $fname_ids{last_fid};
        #
        $last_fname_ids{$filename} = $fname_ids{last_fid};
        #
        if ((($fname_ids{last_fid}%MAX_RECORDS_BEFORE_WRITE) == 0) &&
            (write_filename_id() != SUCCESS))
        {
            printf $log_fh "\t%d: ERROR: Unable to write FNAME_TO_FID.\n", __LINE__;
            die "Writing FILENAME_TO_IDS failed.";
        }
    }
    #
    return $fname_ids{fname_to_fid}{$filename};
}
#
sub process_data
{
    my ($prod_file, $praw_data, $pprod_db) = @_;
    #
    printf $log_fh "\t%d: Processing product data: %s\n", 
                   __LINE__, $prod_file;
    #
    my $max_rec = scalar(@{$praw_data});
    my $sec_no = 0;
    #
    for (my $irec=0; $irec<$max_rec; )
    {
        my $rec = $praw_data->[$irec];
        #
        if ($rec =~ m/^(\[[^\]]*\])/)
        {
            my $section = ${1};
            #
            if (($filter_sections == TRUE) &&
                 ( ! exists($sections{$section})))
            {
                $irec += 1;
                next;
            }
            #
            printf $log_fh "\t\t%d: Section %03d: %s\n", 
                __LINE__, ++$sec_no, $section
                if ($verbose >= MINVERBOSE);
            #
            $rec = $praw_data->[${irec}+1];
            #
            if ($rec =~ m/^\s*$/)
            {
                $irec += 2;
                printf $log_fh "\t\t%d: Empty section - %s\n", 
                               __LINE__, $section;
            }
            elsif ($rec =~ m/.*=.*/)
            {
                load_name_value($praw_data, 
                                $section, 
                               \$irec, 
                                $max_rec,
                                $pprod_db);
            }
            else
            {
                load_list($praw_data, 
                          $section, 
                         \$irec, 
                          $max_rec,
                          $pprod_db);
            }
        }
        else
        {
            $irec += 1;
        }
    }
    #
    return SUCCESS;
}
#
sub export_list_to_csv
{
    my ($prod_file, $prod_name, $pprod_db, $prod_dir, $section) = @_;
    #
    my $combine_lot_file = FALSE;
    $combine_lot_file = TRUE if (($section =~ m/<([0-9]+)>/) &&
                                 ($combine_lot_files == TRUE));
    #
    my $lotno = -1;
    my $csv_file = $section;
    $csv_file =~ s/[\[\]]//g;
    if ($combine_lot_file == TRUE)
    {
        $csv_file =~ s/<([0-9]+)>//g;
        $lotno = $1;
    }
    else
    {
        $csv_file =~ s/<([0-9]+)>/_$1/g;
    }
    #
    my $outnm = $prod_dir . '/' . $csv_file . ".csv";
    #
    my $print_cols = FALSE;
    $print_cols = TRUE if ( ! -r $outnm );
    #
    open(my $outfh, "+>>" , $outnm) || die $!;
    #
    if ($combine_lot_file == TRUE)
    {
        if ($combine_data == COMBINE_BY_FILENAME)
        {
            my $pcols = $pprod_db->{$section}->{column_names};
            if ($print_cols == TRUE)
            {
                printf $outfh "PRODUCT%sLOTNO", $delimiter;
                foreach my $col (@{$pcols})
                {
                    printf $outfh "%s%s", $delimiter, $col;
                }
                printf $outfh "\n";
            }
            #
            foreach my $prow (@{$pprod_db->{$section}->{data}})
            {
                printf $outfh "%s%s%s", $prod_name, $delimiter, $lotno;
                foreach my $col (@{$pcols})
                {
                    printf $outfh "%s%s", $delimiter, $prow->{$col};
                }
                printf $outfh "\n";
            }
        }
        elsif ($combine_data == COMBINE_BY_FILENAME_ID)
        {
            my $fid = get_filename_id($prod_name);
            #
            my $pcols = $pprod_db->{$section}->{column_names};
            if ($print_cols == TRUE)
            {
                printf $outfh "FID%sLOTNO", $delimiter;
                foreach my $col (@{$pcols})
                {
                    printf $outfh "%s%s", $delimiter, $col;
                }
                printf $outfh "\n";
            }
            #
            foreach my $prow (@{$pprod_db->{$section}->{data}})
            {
                printf $outfh "%s%s%s", $fid, $delimiter, $lotno;
                foreach my $col (@{$pcols})
                {
                    printf $outfh "%s%s", $delimiter, $prow->{$col};
                }
                printf $outfh "\n";
            }
        }
        else
        {
            my $pcols = $pprod_db->{$section}->{column_names};
            if ($print_cols == TRUE)
            {
                printf $outfh "LOTNO";
                foreach my $col (@{$pcols})
                {
                    printf $outfh "%s%s", $delimiter, $col;
                }
                printf $outfh "\n";
            }
            #
            foreach my $prow (@{$pprod_db->{$section}->{data}})
            {
                printf $outfh "%s", $lotno;
                foreach my $col (@{$pcols})
                {
                    printf $outfh "%s%s", $delimiter, $prow->{$col};
                }
                printf $outfh "\n";
            }
        }
    }
    else
    {
        if ($combine_data == COMBINE_BY_FILENAME)
        {
            my $pcols = $pprod_db->{$section}->{column_names};
            if ($print_cols == TRUE)
            {
                printf $outfh "PRODUCT";
                foreach my $col (@{$pcols})
                {
                    printf $outfh "%s%s", $delimiter, $col;
                }
                printf $outfh "\n";
            }
            #
            foreach my $prow (@{$pprod_db->{$section}->{data}})
            {
                printf $outfh "%s", $prod_name;
                foreach my $col (@{$pcols})
                {
                    printf $outfh "%s%s", $delimiter, $prow->{$col};
                }
                printf $outfh "\n";
            }
        }
        elsif ($combine_data == COMBINE_BY_FILENAME_ID)
        {
            my $fid = get_filename_id($prod_name);
            #
            my $pcols = $pprod_db->{$section}->{column_names};
            if ($print_cols == TRUE)
            {
                printf $outfh "FID";
                foreach my $col (@{$pcols})
                {
                    printf $outfh "%s%s", $delimiter, $col;
                }
                printf $outfh "\n";
            }
            #
            foreach my $prow (@{$pprod_db->{$section}->{data}})
            {
                printf $outfh "%s", $fid;
                foreach my $col (@{$pcols})
                {
                    printf $outfh "%s%s", $delimiter, $prow->{$col};
                }
                printf $outfh "\n";
            }
        }
        else
        {
            my $pcols = $pprod_db->{$section}->{column_names};
            if ($print_cols == TRUE)
            {
                my $comma = "";
                foreach my $col (@{$pcols})
                {
                    printf $outfh "%s%s", $comma, $col;
                    $comma = $delimiter;
                }
                printf $outfh "\n";
            }
            #
            foreach my $prow (@{$pprod_db->{$section}->{data}})
            {
                my $comma = "";
                foreach my $col (@{$pcols})
                {
                    printf $outfh "%s%s", $comma, $prow->{$col};
                    $comma = $delimiter;
                }
                printf $outfh "\n";
            }
        }
    }
    #
    close($outfh);
}
#
sub export_name_value_to_csv
{
    my ($prod_file, $prod_name, $pprod_db, $prod_dir, $section) = @_;
    #
    my $combine_lot_file = FALSE;
    $combine_lot_file = TRUE if (($section =~ m/<([0-9]+)>/) &&
                                 ($combine_lot_files == TRUE));
    #
    my $lotno = -1;
    my $csv_file = $section;
    $csv_file =~ s/[\[\]]//g;
    if ($combine_lot_file == TRUE)
    {
        $csv_file =~ s/<([0-9]+)>//g;
        $lotno = $1;
    }
    else
    {
        $csv_file =~ s/<([0-9]+)>/_$1/g;
    }
    #
    my $outnm = $prod_dir . '/' . $csv_file . ".csv";
    #
    my $print_cols = FALSE;
    $print_cols = TRUE if ( ! -r $outnm );
    #
    open(my $outfh, "+>>" , $outnm) || die $!;
    #
    if ($combine_lot_file == TRUE)
    {
        if ($combine_data == COMBINE_BY_FILENAME)
        {
            if ($print_cols == TRUE)
            {
                printf $outfh "PRODUCT%sLOTNO%sNAME%sVALUE\n", 
                    $delimiter, 
                    $delimiter, 
                    $delimiter;
            }
            #
            foreach my $key (keys %{$pprod_db->{$section}->{data}})
            {
                printf $outfh "%s%s%s%s%s%s%s\n", 
                    $prod_name, 
                    $delimiter,
                    $lotno, 
                    $delimiter,
                    $key, 
                    $delimiter,
                    $pprod_db->{$section}->{data}->{$key};
            }
        }
        elsif ($combine_data == COMBINE_BY_FILENAME_ID)
        {
            my $fid = get_filename_id($prod_name);
            #
            if ($print_cols == TRUE)
            {
                printf $outfh "FID%sLOTNO%sNAME%sVALUE\n", 
                    $delimiter, 
                    $delimiter, 
                    $delimiter;
            }
            #
            foreach my $key (keys %{$pprod_db->{$section}->{data}})
            {
                printf $outfh "%s%s%s%s%s%s%s\n", 
                    $fid, 
                    $delimiter,
                    $lotno, 
                    $delimiter,
                    $key, 
                    $delimiter,
                    $pprod_db->{$section}->{data}->{$key};
            }
        }
        else
        {
            if ($print_cols == TRUE)
            {
                printf $outfh "LOTNO%sNAME%sVALUE\n", 
                    $delimiter, 
                    $delimiter;
            }
            #
            foreach my $key (keys %{$pprod_db->{$section}->{data}})
            {
                printf $outfh "%s%s%s%s%s\n", 
                    $lotno, 
                    $delimiter,
                    $key, 
                    $delimiter,
                    $pprod_db->{$section}->{data}->{$key};
            }
        }
    }
    else
    {
        if ($combine_data == COMBINE_BY_FILENAME)
        {
            if ($print_cols == TRUE)
            {
                printf $outfh "PRODUCT%sNAME%sVALUE\n", 
                    $delimiter, 
                    $delimiter;
            }
            #
            foreach my $key (keys %{$pprod_db->{$section}->{data}})
            {
                printf $outfh "%s%s%s%s%s\n", 
                    $prod_name, 
                    $delimiter,
                    $key, 
                    $delimiter,
                    $pprod_db->{$section}->{data}->{$key};
            }
        }
        elsif ($combine_data == COMBINE_BY_FILENAME_ID)
        {
            my $fid = get_filename_id($prod_name);
            #
            if ($print_cols == TRUE)
            {
                printf $outfh "FID%sNAME%sVALUE\n", 
                    $delimiter, 
                    $delimiter;
            }
            #
            foreach my $key (keys %{$pprod_db->{$section}->{data}})
            {
                printf $outfh "%s%s%s%s%s\n", 
                    $fid, 
                    $delimiter,
                    $key, 
                    $delimiter,
                    $pprod_db->{$section}->{data}->{$key};
            }
        }
        else
        {
            if ($print_cols == TRUE)
            {
                printf $outfh "NAME%sVALUE\n", $delimiter;
            }
            #
            foreach my $key (keys %{$pprod_db->{$section}->{data}})
            {
                printf $outfh "%s%s%s\n", 
                    $key, 
                    $delimiter,
                    $pprod_db->{$section}->{data}->{$key};
            }
        }
    }
    #
    close($outfh);
}
#
sub export_to_csv
{
    my ($prod_file, $pprod_db) = @_;
    #
    printf $log_fh "\t%d: Writing product data to CSV: %s\n", 
                   __LINE__, $prod_file;
    #
    my $prod_name = basename($prod_file);
    $prod_name =~ tr/a-z/A-Z/;
    #
    my $prod_csv_dir = '';
    if ($combine_data == COMBINE_BY_FILENAME)
    {
        $prod_csv_dir = $csv_path . '/COMBINED';
        ( mkpath($prod_csv_dir) || die $! ) unless ( -d $prod_csv_dir );
    }
    elsif ($combine_data == COMBINE_BY_FILENAME_ID)
    {
        $prod_csv_dir = $csv_path . '/COMBINED';
        ( mkpath($prod_csv_dir) || die $! ) unless ( -d $prod_csv_dir );
        #
        if ($fname_ids{initialized} != TRUE)
        {
            if (read_filename_id($prod_csv_dir) != SUCCESS)
            {
                printf $log_fh "\t%d: ERROR: Unable to read FNAME_TO_FID: %s\n", 
                   __LINE__, $prod_file;
                die "Reading FILENAME_TO_IDS failed.";
            }
        }
    }
    else
    {
        $prod_csv_dir = $csv_path . '/CSV_' . $prod_name;
        ( mkpath($prod_csv_dir) || die $! ) unless ( -d $prod_csv_dir );
    }
    #
    printf $log_fh "\t\t%d: product %s CSV directory: %s\n", 
        __LINE__, $prod_name, $prod_csv_dir;
    #
    foreach my $section (sort keys %{$pprod_db->{found_data}})
    {
        if ($pprod_db->{found_data}->{$section} != TRUE)
        {
            printf $log_fh "\t\t%d: No data for section %s. Skipping it.\n", 
                __LINE__, $section if ($verbose >= MINVERBOSE);
        }
        elsif ($pprod_db->{section_type}->{$section} == SECTION_NAME_VALUE)
        {
            printf $log_fh "\t\t%d: Name-Value Section: %s\n", 
                __LINE__, $section;
            export_name_value_to_csv($prod_file,
                                     $prod_name,
                                     $pprod_db,
                                     $prod_csv_dir,
                                     $section);
        }
        elsif ($pprod_db->{section_type}->{$section} == SECTION_LIST)
        {
            printf $log_fh "\t\t%d: List Section: %s\n", 
                __LINE__, $section;
            export_list_to_csv($prod_file,
                               $prod_name,
                               $pprod_db,
                               $prod_csv_dir,
                               $section);
        }
        else
        {
            printf $log_fh "\t\t%d: Unknown type Section: %s\n", 
                __LINE__, $section;
        }
    }
    #
    return SUCCESS;
}
#
sub process_file
{
    my ($prod_file) = @_;
    #
    printf $log_fh "\n%d: Processing product File: %s\n", 
                   __LINE__, $prod_file;
    #
    my @raw_data = ();
    my %prod_db = ();
    #
    my $status = FAIL;
    if (read_file($prod_file, \@raw_data) != SUCCESS)
    {
        printf $log_fh "\t%d: ERROR: Reading product file: %s\n", 
                       __LINE__, $prod_file;
    }
    elsif (process_data($prod_file, \@raw_data, \%prod_db) != SUCCESS)
    {
        printf $log_fh "\t%d: ERROR: Processing product file: %s\n", 
                       __LINE__, $prod_file;
    }
    elsif (export_to_csv($prod_file, \%prod_db) != SUCCESS)
    {
        printf $log_fh "\t%d: ERROR: Exporting product file to CSV: %s\n", 
                       __LINE__, $prod_file;
    }
    else
    {
        printf $log_fh "\t%d: Success processing product file: %s\n", 
                       __LINE__, $prod_file;
        $status = SUCCESS;
    }
    #
    return $status;
}
#
######################################################################
#
my %opts;
if (getopts('?hwWv:B:R:P:l:d:rLCcs:S:', \%opts) != 1)
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
        $rmv_csv_dir = TRUE;
    }
    elsif ($opt eq 'L')
    {
        $combine_lot_files = TRUE;
    }
    elsif ($opt eq 'C')
    {
        $combine_data = COMBINE_BY_FILENAME;
    }
    elsif ($opt eq 'c')
    {
        $combine_data = COMBINE_BY_FILENAME_ID;
    }
    elsif ($opt eq 'w')
    {
        $verbose = MINVERBOSE;
    }
    elsif ($opt eq 'W')
    {
        $verbose = MIDVERBOSE;
    }
    elsif ($opt eq 's')
    {
        $filter_sections = TRUE;
        %sections = map { $_ => 1 } split /,/, $opts{$opt};
        $sections{INDEX()} = 1;
        $sections{INFORMATION()} = 1;
        printf $log_fh "\n%d: filter sections: \n%s\n", __LINE__, join("\n", keys %sections);
    }
    elsif ($opt eq 'S')
    {
        $filter_sections = TRUE;
        %sections = map { $_ => 1 } split /,/, $opts{$opt};
        printf $log_fh "\n%d: filter sections: \n%s\n", __LINE__, join("\n", keys %sections);
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
    elsif ($opt eq 'P')
    {
        $csv_path = $opts{$opt} . '/';
        printf $log_fh "\n%d: CSV path: %s\n", __LINE__, $csv_path;
    }
    elsif ($opt eq 'R')
    {
        $csv_rel_path = $opts{$opt} . '/';
        $csv_path = $csv_base_path . '/' . $csv_rel_path;
        printf $log_fh "\n%d: CSV relative path: %s\n", __LINE__, $csv_rel_path;
    }
    elsif ($opt eq 'B')
    {
        $csv_base_path = $opts{$opt} . '/';
        $csv_path = $csv_base_path . '/' . $csv_rel_path;
        printf $log_fh "\n%d: CSV base path: %s\n", __LINE__, $csv_base_path;
    }
    elsif ($opt eq 'd')
    {
        $delimiter = $opts{$opt};
        $delimiter = "\t" if ( $delimiter =~ /^$/ );
    }
}
#
if ( -t STDIN )
{
    #
    # getting a list of files from command line.
    #
    if (scalar(@ARGV) == 0)
    {
        printf $log_fh "%d: ERROR: No product files given.\n", __LINE__;
        usage($cmd);
        exit 2;
    }
    #
    rmtree($csv_path) if ($rmv_csv_dir == TRUE);
    ( mkpath($csv_path) || die $! ) unless ( -d $csv_path );
    #
    foreach my $prod_file (@ARGV)
    {
        process_file($prod_file);
    }
    #
}
else
{
    printf $log_fh "%d: Reading STDIN for list of files ...\n", __LINE__;
    #
    rmtree($csv_path) if ($rmv_csv_dir == TRUE);
    ( mkpath($csv_path) || die $! ) unless ( -d $csv_path );
    #
    while( defined(my $prod_file = <STDIN>) )
    {
        chomp($prod_file);
        process_file($prod_file);
    }
}
#
if (($combine_data == COMBINE_BY_FILENAME_ID) &&
    ($fname_ids{initialized} == TRUE))
{
    if (write_filename_id() != SUCCESS)
    {
        printf $log_fh "\t%d: ERROR: Unable to write FNAME_TO_FID.\n", __LINE__;
        die "Writing FILENAME_TO_IDS failed.";
    }
}
#
exit 0;
