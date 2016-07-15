#!/usr/bin/perl -w
######################################################################
#
# read a list of csv files and create a sqlite3 database.
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
my $dbh = undef;
my $create_fid_index = FALSE;
#
# cmd line options
#
my $logfile = '';
my $rmv_old_db = FALSE;
my $delimiter = "\t";
#
my $db_base_path = undef;
$db_base_path = $ENV{'OMBT_DB_BASE_PATH'} 
    if (exists($ENV{'OMBT_DB_BASE_PATH'}));
$db_base_path = "." 
    unless (defined($db_base_path) and ($db_base_path ne ""));
#
my $db_rel_path = undef;
$db_rel_path = $ENV{'OMBT_DB_REL_PATH'} 
    if (exists($ENV{'OMBT_DB_REL_PATH'}));
$db_rel_path = "CSV2DB" 
    unless (defined($db_rel_path) and ($db_rel_path ne ""));
#
my $db_path = $db_base_path . '/' . $db_rel_path;
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
        [-B base path]
        [-R relative path]
        [-P path]
        [-d delimiter]
        [-f] [-r] 
        CSV-file ...

where:
    -? or -h - print this usage.
    -l logfile - log file path
    -B path - base db path, defaults to '${db_base_path}'
              or use environment variable OMBT_DB_BASE_PATH.
    -R path - relative db path, defaults to '${db_rel_path}'
              or use environment variable OMBT_DB_REL_PATH.
    -P path - db path, defaults to '${db_path}'
    -d delimiter - CSV delimiter characer. default is a tab.
    -f - create filename ID index if table has FID field.
    -r - remove old DB

EOF
}
#
######################################################################
#
# db functions
#
sub table_exists
{
    my ($dbh, $table_name) = @_;
    my $sth = $dbh->table_info(undef, undef, $table_name, 'TABLE');
    $sth->execute;
    my @info = $sth->fetchrow_array;
    if (scalar(@info) > 0)
    {
        return TRUE;
    }
    else
    {
        return FALSE;
    }
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
    # get table name
    #
    (my $tbl_name = $csv_file) =~ s/\.csv$//i;
    $tbl_name =~ s/\./_/g;
    $tbl_name = basename($tbl_name);
    printf $log_fh "%d: Table: %s\n", __LINE__, $tbl_name;
    #
    # check if table exists.
    #
    if (table_exists($dbh, $tbl_name) == FALSE)
    {
        printf $log_fh "%d: Creating table %s\n", __LINE__, $tbl_name;
        my $create_tbl_sql = "create table '${tbl_name}' ( '" . join("' varchar(100), '", @{col_names}) . "' varchar(100) )";
        #
        $dbh->do($create_tbl_sql);
        $dbh->commit();
        #
        if (($create_fid_index == TRUE) &&
            (grep( /^FID$/i, @{col_names})))
        {
            printf $log_fh "%d: Creating table %s index\n", __LINE__, $tbl_name;
            my $create_idx_sql = "create index ${tbl_name}_fid_idx on '${tbl_name}' ( FID )";
            $dbh->do($create_idx_sql);
            $dbh->commit();
        }
    }
    #
    # generate insert sql command
    #
    my $insert_fields = "insert into '${tbl_name}' ( '" . join("','", @col_names) . "')";
    #
    my $do_commit = FALSE;
    while (my $row = <$infh>)
    {
        #
        # parse the data and remove any junk characters.
        #
        chomp($row);
        $row =~ s/\r//g;
        my @data = split /${delimiter}/, $row, -1;
        my $insert_sql = $insert_fields . " values ( '" . join("','", @data) . "')";
        if ( ! eval { $dbh->do($insert_sql); 1; } ) 
        {
            printf $log_fh "%d: ERROR: INSERT FAILED: %s\nSQL: %s\n", __LINE__, $@, $insert_sql;
        }
        else
        {
            $do_commit = TRUE;
        }
    }
    #
    $dbh->commit() if ($do_commit == TRUE);
    #
    return;
}
#
######################################################################
#
my %opts;
if (getopts('?hB:R:P:l:d:rf', \%opts) != 1)
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
    elsif ($opt eq 'P')
    {
        $db_path = $opts{$opt} . '/';
        printf $log_fh "\n%d: DB path: %s\n", __LINE__, $db_path;
    }
    elsif ($opt eq 'R')
    {
        $db_rel_path = $opts{$opt};
        $db_path = $db_base_path . '/' . $db_rel_path;
        printf $log_fh "\n%d: DB relative path: %s\n", __LINE__, $db_rel_path;
    }
    elsif ($opt eq 'B')
    {
        $db_base_path = $opts{$opt} . '/';
        $db_path = $db_base_path . '/' . $db_rel_path;
        printf $log_fh "\n%d: DB base path: %s\n", __LINE__, $db_base_path;
    }
    elsif ($opt eq 'r')
    {
        $rmv_old_db = TRUE;
    }
    elsif ($opt eq 'f')
    {
        $create_fid_index = TRUE;
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
# check if remove old data.
#
unlink($db_path) if ($rmv_old_db == TRUE);
#
# create db if needed.
#
if ( ! -f $db_path )
{
    printf $log_fh "\n%d: Using new DB: %s.\n", __LINE__, $db_path;
}
else
{
    printf $log_fh "\n%d: Re-using existing DB: %s.\n", __LINE__, $db_path;
}
my $dsn = "dbi:SQLite:dbname=${db_path}";
my $user = "";
my $password = "";
#
# process each file and place data into db.
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
    $dbh = DBI->connect($dsn,
                        $user,
                        $password,
                        {
                            PrintError => 0,
                            RaiseError => 1,
                            AutoCommit => 0,
                            FetchHashKeyName => 'NAME_lc'
                        });
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
    $dbh = DBI->connect($dsn,
                        $user,
                        $password,
                        {
                            PrintError => 0,
                            RaiseError => 1,
                            AutoCommit => 0,
                            FetchHashKeyName => 'NAME_lc'
                        });
    #
    while( defined(my $csv_file = <STDIN>) )
    {
        chomp($csv_file);
        process_file($csv_file);
    }
}
#
# close db
#
printf $log_fh "\n%d: Closing DB: %s.\n", __LINE__, $db_path;
$dbh->disconnect;
#
exit 0;
