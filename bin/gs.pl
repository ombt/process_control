#!/usr/bin/perl -w
#
################################################################
#
# generic server for stream/datagram and socket/unix.
#
################################################################
#
use strict;
#
my $binpath;
#
BEGIN
{
    use File::Basename;
    #
    $binpath = dirname($0);
    $binpath = "." if ($binpath eq "");
}
#
# perl mods
#
use Getopt::Std;
use Socket;
use FileHandle;
use POSIX qw(:errno_h);
#
# my mods
#
use lib $binpath;
#
use myconstants;
use mylogger;
use mytimer;
use mytimerpqueue;
use mytaskdata;
use mylnbxml;
#
################################################################
#
# local constants
#
use constant SOCKET_STREAM => 'SOCKET_STREAM';
use constant SOCKET_DATAGRAM => 'SOCKET_DATAGRAM';
use constant UNIX_STREAM => 'UNIX_STREAM';
use constant UNIX_DATAGRAM => 'UNIX_DATAGRAM';
use constant TTY_STREAM => 'TTY_STREAM';
#
use constant SOH => 1;
use constant STX => 2;
use constant ETX => 3;
#
################################################################
#
# globals
#
my $cmd = $0;
my $default_cfg_file = "generic-server.cfg";
#
my $plog = mylogger->new();
die "Unable to create logger: $!" unless (defined($plog));
#
my $pq = mytimerpqueue->new();
die "Unable to create priority queue: $!" unless (defined($pq));
#
# default service values
#
my %default_service_params =
(
    name => {
        use_default => FALSE(),
        default_value => "",
        translate => undef,
    },
    type => {
        use_default => TRUE(),
        default_value => SOCKET_STREAM(),
        translate => \&to_uc,
    },
    host_name => {
        use_default => TRUE(),
        default_value => "localhost",
        translate => undef,
    },
    file_name => {
        use_default => TRUE(),
        default_value => "",
        translate => undef,
    },
    port => {
        use_default => TRUE(),
        default_value => -1,
        translate => undef,
    },
    service => {
        use_default => TRUE(),
        default_value => undef,
        translate => undef,
    },
    client => {
        use_default => TRUE(),
        default_value => FALSE(),
        translate => undef,
    },
    io_handler => {
        use_default => TRUE(),
        default_value => undef,
        translate => undef,
    },
    service_handler => {
        use_default => TRUE(),
        default_value => undef,
        translate => undef,
    },
    timer_handler => {
        use_default => TRUE(),
        default_value => undef,
        translate => undef,
    },
    ctor => {
        use_default => TRUE(),
        default_value => undef,
        translate => undef,
    },
    client_io_handler => {
        use_default => TRUE(),
        default_value => undef,
        translate => undef,
    },
    client_service_handler => {
        use_default => TRUE(),
        default_value => undef,
        translate => undef,
    },
    client_timer_handler => {
        use_default => TRUE(),
        default_value => undef,
        translate => undef,
    },
    client_ctor => {
        use_default => TRUE(),
        default_value => undef,
        translate => undef,
    },
);
#
# vectors for select()
#
my $rin = '';
my $win = '';
my $ein = '';
#
my $rout = '';
my $wout = '';
my $eout = '';
#
# map connection type to create connection routine
#
my %create_connection =
(
    SOCKET_STREAM() => \&create_socket_stream,
    SOCKET_DATAGRAM() => \&create_socket_dgram,
    UNIX_STREAM() => \&create_unix_stream,
    UNIX_DATAGRAM() => \&create_unix_dgram,
    TTY_STREAM() => undef
);
#
# private data for each service instance
#
my $pservices = mytaskdata->new();
die "Unable to create services data: $!" 
    unless (defined($pservices));
#
my $pfh_services = mytaskdata->new();
die "Unable to create file-handler-to-services data: $!" 
    unless (defined($pfh_services));
#
my $pfh_data = mytaskdata->new();
die "Unable to create task-specific data: $!" 
    unless (defined($pfh_data));
#
# misc
#
my $event_loop_done = FALSE;
#
################################################################
#
# misc functions
#
sub usage
{
    my ($arg0) = @_;
    my $log_fh = $plog->log_fh();
    print $log_fh <<EOF;

usage: $arg0 [-?] [-h]  \\ 
        [-w | -W |-v level] \\ 
        [-l logfile] \\ 
        [config-file [config-file2 ...]]

where:
    -? or -h - print this usage.
    -w - enable warning (level=min=1)
    -W - enable warning and trace (level=mid=2)
    -v - verbose level: 0=off,1=min,2=mid,3=max
    -l logfile - log file path

config-file is the configuration file containing lists of
services to create. one or more config files can be given.
if a config file is not given, then the default is to look
for the file generic-server.cfg in the current directory.

EOF
}
#
################################################################
#
# read and parse data files.
#
sub read_file
{
    my ($file_nm, $praw_data) = @_;
    #
    if ( ! -r $file_nm )
    {
        $plog->log_err("File %s is NOT readable\n", $file_nm);
        return FAIL;
    }
    #
    unless (open(INFD, $file_nm))
    {
        $plog->log_err("Unable to open %s.\n", $file_nm);
        return FAIL;
    }
    @{$praw_data} = <INFD>;
    close(INFD);
    #
    # remove any CR-NL sequences from Windose.
    chomp(@{$praw_data});
    s/\r//g for @{$praw_data};
    #
    $plog->log_vmin("Lines read: %d\n", scalar(@{$praw_data}));
    return SUCCESS;
}
#
sub fill_in_missing_data
{
    my ($pservice) = @_;
    #
    foreach my $key (keys %default_service_params)
    {
        if (( ! exists($pservice->{$key})) &&
            ($default_service_params{$key}{use_default} == TRUE))
        {
            $plog->log_vmin("Defaulting missing %s field.\n", $key);
            $pservice->{$key} = $default_service_params{$key}{default_value};
        }
    }
}
#
sub to_uc
{
    my ($in) = @_;
    return uc($in);
}
#
sub parse_file
{
    my ($pdata) = @_;
    #
    my $lnno = 0;
    my $pservice = { };
    #
    foreach my $record (@{$pdata})
    {
        $plog->log_vmin("Processing record (%d) : %s\n", ++$lnno, $record);
        #
        if (($record =~ m/^\s*#/) || ($record =~ m/^\s*$/))
        {
            # skip comments or white-space-only lines
            next;
        }
        elsif ($record =~ m/^\s*service\s*start\s*$/)
        {
            $pservice = { };
        }
        elsif ($record =~ m/^\s*service\s*end\s*$/)
        {
            if ((exists($pservice->{name})) &&
                ($pservice->{name} ne ""))
            {
                my $name = $pservice->{name};
                #
                $plog->log_msg("Storing service: %s\n", $name);
                #
                die "ERROR: duplicate service $name: $!" 
                    if ($pservices->exists($name) == TRUE);
                #
                fill_in_missing_data($pservice);
                $pservices->set($name, $pservice);
            }
            else
            {
                $plog->log_err("Unknown service name (%d).\n", $lnno);
                return FAIL;
            }
            #
            $pservice = { };
        }
        else
        {
            my $found = FALSE;
            foreach my $key (keys %default_service_params)
            {
                if ($record =~ m/^\s*${key}\s*=\s*(.*)$/i)
                {
                    $plog->log_vmin("Setting %s to %s (%d)\n", $key, ${1}, $lnno);
                    if (defined($default_service_params{$key}{translate}))
                    {
                        # massage the data value
                        $pservice->{$key} = 
                            &{$default_service_params{$key}{translate}}(${1});
                    }
                    else
                    {
                        $pservice->{$key} = ${1};
                    }
                    $found = TRUE;
                    last;
                }
            }
            if ($found == FALSE)
            {
                $plog->log_err_exit("Unknown record %d: %s\n", $lnno, $record);
            }
        }
    }
    #
    return SUCCESS;
}
#
sub read_cfg_file
{
    my ($cfgfile) = @_;
    #
    my @data = ();
    if ((read_file($cfgfile, \@data) == SUCCESS) &&
	(parse_file(\@data) == SUCCESS))
    {
        $plog->log_vmin("Successfully processed cfg file %s.\n", $cfgfile);
        return SUCCESS;
    }
    else
    {
        $plog->log_err("Processing cfg file %s failed.\n", $cfgfile);
        return FAIL;
    }
}
#
################################################################
#
# default timer, io and service handlers
#
sub null_timer_handler
{
    my ($ptimer, $pservice) = @_;
    #
    $plog->log_vmin("null timer handler ... %s\n", $ptimer->{label});
}
#
sub stdin_timer_handler
{
    my ($ptimer, $pservice) = @_;
    #
    $plog->log_vmin("sanity timer handler ... %s\n", $ptimer->{label});
    #
    start_timer($ptimer->{fileno},
                $ptimer->{delta},
                $ptimer->{label});
}
#
sub stdin_handler
{
    my ($pservice) = @_;
    #
    my $data = <STDIN>;
    chomp($data);
    #
    if (defined($data))
    {
        $plog->log_msg("input ... <%s>\n", $data);
        if ($data =~ m/^q$/i)
        {
            $event_loop_done = TRUE;
        }
        elsif (($data =~ m/^[h?]$/i) ||
               ($data eq ""))
        {
            my $log_fh = $plog->log_fh();
            print $log_fh <<EOF;
Available commnds:
    q - quit
    ? - help
    h - help
    l - list services
    s - print services
    lc - list clients
    cc <fileno> - close client
    t - print timers
EOF
        }
        elsif ($data =~ m/^s$/i)
        {
            my $pfhit = $pfh_services->iterator('n');
            while (defined(my $fileno = $pfhit->()))
            {
                my $pservice = $pfh_services->get($fileno);
                $plog->log_msg("FileNo: %d, Service: %s\n", 
                               $fileno,
                               $pservice->{name});
                if ((defined($pservice->{port})) &&
                    ($pservice->{port} > 0))
                    
                {
                    $plog->log_msg("FileNo: %d, Port: %s\n", 
                               $fileno,
                               $pservice->{port});
                }
                if ((defined($pservice->{file_name})) &&
                    ($pservice->{file_name} ne ""))
                {
                    $plog->log_msg("FileNo: %d, File Name: %s\n", 
                               $fileno,
                               $pservice->{file_name});
                }
            }             
        }
        elsif ($data =~ m/^l$/i)
        {
            my $pfhit = $pfh_services->iterator('n');
            while (defined(my $fileno = $pfhit->()))
            {
                my $pservice = $pfh_services->get($fileno);
                $plog->log_msg("FileNo: %d, Service: %s\n", 
                               $fileno,
                               $pservice->{name});
            }             
        }
        elsif ($data =~ m/^lc$/i)
        {
            my $pfhit = $pfh_services->iterator('n');
            while (defined(my $fileno = $pfhit->()))
            {
                my $pservice = $pfh_services->get($fileno);
                if ((defined($pservice->{client})) &&
                    ($pservice->{client} == TRUE))
                {
                    $plog->log_msg("Client: FileNo: %d, Service: %s\n", 
                                   $fileno,
                                   $pservice->{name});
                }
            }             
        }
        elsif ($data =~ m/^cc\s*(\d+)\s*$/i)
        {
            my $fileno_to_close = $1;
            if (defined($fileno_to_close) && ($fileno_to_close >= 0))
            {
                my $pfhit = $pfh_services->iterator('n');
                while (defined(my $fileno = $pfhit->()))
                {
                    my $pservice = $pfh_services->get($fileno);
                    if ((defined($pservice->{client})) &&
                        ($pservice->{client} == TRUE) &&
                        ($fileno == $fileno_to_close))
                    {
                        $plog->log_msg("Closing Client: FileNo: %d, Service: %s\n", 
                                       $fileno,
                                       $pservice->{name});
                        vec($rin, $fileno, 1) = 0;
                        vec($ein, $fileno, 1) = 0;
                        vec($win, $fileno, 1) = 0;
                        #
                        my $pfh = $pservice->{fh};
                        close($$pfh);
                        #
                        $plog->log_msg("closing socket (%d) for service %s ...\n", 
                                       $fileno,
                                       $pservice->{name});
                        $pfh_services->deallocate($fileno);
                        $pfh_data->deallocate($fileno);
                    }
                }             
            }
            else
            {
                $plog->log_msg("Invalid client file no.\n");
            }
        }
        elsif ($data =~ m/^t$/i)
        {
            $pq->dump();
        }
    }
}
#
sub generic_stream_io_handler
{
    my ($pservice) = @_;
    #
    $plog->log_msg("entering generic_stream_handler() for %s\n", 
                   $pservice->{name});
    #
    my $pfh = $pservice->{fh};
    my $fileno = fileno($$pfh);
    #
    my $nr = 0;
    my $buffer = undef;
    while (defined($nr = sysread($$pfh, $buffer, 1024*4)) && ($nr > 0))
    {
        my $local_buffer = unpack("H*", $buffer);
        $plog->log_msg("nr ... <%d>\n", $nr);
        $plog->log_msg("buffer ... <%s>\n", $buffer);
        $plog->log_msg("unpacked buffer ... <%s>\n", $local_buffer);
        #
        $pfh_data->set($fileno, 'input', $buffer);
        $pfh_data->set($fileno, 'input_length', $nr);
        &{$pservice->{service_handler}}($pservice);
    }
    #
    if ((( ! defined($nr)) && ($! != EAGAIN)) ||
        (defined($nr) && ($nr == 0)))
    {
        #
        # EOF or some error
        #
        vec($rin, $fileno, 1) = 0;
        vec($ein, $fileno, 1) = 0;
        vec($win, $fileno, 1) = 0;
        #
        close($$pfh);
        #
        $plog->log_msg("closing socket (%d) for service %s ...\n", 
                       $fileno,
                       $pservice->{name});
        $pfh_services->deallocate($fileno);
        $pfh_data->deallocate($fileno);
    }
}
#
sub generic_stream_service_handler
{
    my ($pservice) = @_;
    #
    my $pfh = $pservice->{fh};
    my $fileno = fileno($$pfh);
    #
    my $nr = $pfh_data->get($fileno, 'input_length');
    my $buffer = $pfh_data->get($fileno, 'input');
    #
    die $! if ( ! defined(send($$pfh, $buffer, $nr)));
}
#
sub generic_datagram_io_handler
{
    my ($pservice) = @_;
    #
    $plog->log_msg("entering generic_datagram_io_handler() for %s\n", 
                   $pservice->{name});
    #
    my $pfh = $pservice->{fh};
    my $fileno = fileno($$pfh);
    #
    my $recvpaddr = undef;
    my $buffer = undef;
    while (defined($recvpaddr = recv($$pfh, $buffer, 1024*4, 0)))
    {
        my $local_buffer = unpack("H*", $buffer);
        $plog->log_msg("buffer ... <%s>\n", $buffer);
        $plog->log_msg("unpacked buffer ... <%s>\n", $local_buffer);
        #
        $pfh_data->set($fileno, 'input', $buffer);
        $pfh_data->set($fileno, 'input_length', length($buffer));
        $pfh_data->set($fileno, 'recvpaddr', $recvpaddr);
        &{$pservice->{service_handler}}($pservice);
    }
    #
    if (( ! defined($recvpaddr)) && ($! != EAGAIN))
    {
        #
        # EOF or some error
        #
        vec($rin, $fileno, 1) = 0;
        vec($ein, $fileno, 1) = 0;
        vec($win, $fileno, 1) = 0;
        #
        close($$pfh);
        #
        $plog->log_msg("closing socket (%d) for service %s ...\n", 
                       $fileno,
                       $pservice->{name});
        $pfh_services->deallocate($fileno);
        $pfh_data->deallocate($fileno);
    }
}
#
sub generic_datagram_service_handler
{
    my ($pservice) = @_;
    #
    my $pfh = $pservice->{fh};
    my $fileno = fileno($$pfh);
    #
    my $nr = $pfh_data->get($fileno, 'input_length');
    my $buffer = $pfh_data->get($fileno, 'input');
    my $recvpaddr = $pfh_data->get($fileno, 'recvpaddr');
    #
    die $! if ( ! defined(send($$pfh, $buffer, 0, $recvpaddr)));
}
#
sub socket_stream_accept_io_handler
{
    my ($pservice) = @_;
    #
    # do the accept
    #
    my $pfh = $pservice->{fh};
    # my $new_fh = FileHandle->new();
    my $new_fh = undef;
    if (my $client_paddr = accept($new_fh, $$pfh))
    {
        $plog->log_msg("accept() succeeded for service %s\n", $pservice->{name});
        #
        fcntl($new_fh, F_SETFL, O_NONBLOCK);
        #
        my ($client_port, $client_packed_ip) = sockaddr_in($client_paddr);
        my $client_ascii_ip = inet_ntoa($client_packed_ip);
        #
        vec($rin, fileno($new_fh), 1) = 1;
        vec($ein, fileno($new_fh), 1) = 1;
        #
        my $io_handler = undef;
        die "unknown client io handler: $!" 
            unless (exists($pservice->{client_io_handler}));
        $io_handler = $pservice->{client_io_handler};
        #
        my $service_handler = undef;
        die "unknown client service handler: $!" 
            unless (exists($pservice->{client_service_handler}));
        $service_handler = $pservice->{client_service_handler};
        #
        my $timer_handler = $pservice->{client_timer_handler};
        #
        my $pnew_service = 
        {
            client => TRUE(),
            name => "client_of_" . $pservice->{name},
            client_port => $client_port,
            client_host_name => $client_ascii_ip,
            client_paddr => $client_paddr,
            fh => \$new_fh,
            io_handler => $io_handler,
            service_handler => $service_handler,
            timer_handler => $timer_handler,
            total_buffer => "",
        };
        #
        my $fileno = fileno($new_fh);
        $pfh_services->set($fileno, $pnew_service);
        $pfh_data->reallocate($fileno);
        #
        # call ctor if it exists.
        #
        my $ctor = $pservice->{'ctor'};
        if (defined($ctor))
        {
            my $status = &{$ctor}($pnew_service);
        }
    }
    else
    {
        $plog->log_err("accept() failed for service %s\n", $pservice->{name});
    }
}
#
sub unix_stream_accept_io_handler
{
    my ($pservice) = @_;
    #
    # do the accept
    #
    my $pfh = $pservice->{fh};
    # my $new_fh = FileHandle->new();
    my $new_fh = undef;
    if (my $client_paddr = accept($new_fh, $$pfh))
    {
        $plog->log_msg("accept() succeeded for service %s\n", $pservice->{name});
        #
        fcntl($new_fh, F_SETFL, O_NONBLOCK);
        #
        my ($client_filename) = sockaddr_un($client_paddr);
        #
        vec($rin, fileno($new_fh), 1) = 1;
        vec($ein, fileno($new_fh), 1) = 1;
        #
        my $io_handler = undef;
        die "unknown client handler: $!" 
            unless (exists($pservice->{client_io_handler}));
        $io_handler = $pservice->{client_io_handler};
        #
        my $service_handler = undef;
        die "unknown client handler: $!" 
            unless (exists($pservice->{client_service_handler}));
        $service_handler = $pservice->{client_service_handler};
        #
        my $timer_handler = $pservice->{client_timer_handler};
        #
        my $pnew_service = 
        {
            client => TRUE(),
            name => "client_of_" . $pservice->{name},
            client_filename => $client_filename,
            client_paddr => $client_paddr,
            fh => \$new_fh,
            io_handler => $io_handler,
            service_handler => $service_handler,
            timer_handler => $timer_handler,
            total_buffer => "",
        };
        #
        my $fileno = fileno($new_fh);
        $pfh_services->set($fileno, $pnew_service);
        $pfh_data->reallocate($fileno);
        #
        # call ctor if it exists.
        #
        my $ctor = $pservice->{'ctor'};
        if (defined($ctor))
        {
            my $status = &{$ctor}($pnew_service);
        }
    }
    else
    {
        $plog->log_err("accept() failed for service %s\n", $pservice->{name});
    }
}
#
sub socket_stream_accept_service_handler
{
    my ($pservice) = @_;
}
#
sub unix_stream_accept_service_handler
{
    my ($pservice) = @_;
}
#
sub socket_stream_io_handler
{
    my ($pservice) = @_;
    generic_stream_io_handler($pservice);
}
#
sub socket_stream_service_handler
{
    my ($pservice) = @_;
    generic_stream_service_handler($pservice);
}
#
sub socket_datagram_io_handler
{
    my ($pservice) = @_;
    generic_datagram_io_handler($pservice);
}
#
sub socket_datagram_service_handler
{
    my ($pservice) = @_;
    generic_datagram_service_handler($pservice);
}
#
sub unix_stream_io_handler
{
    my ($pservice) = @_;
    generic_stream_io_handler($pservice);
}
#
sub unix_stream_service_handler
{
    my ($pservice) = @_;
    generic_stream_service_handler($pservice);
}
#
sub unix_datagram_io_handler
{
    my ($pservice) = @_;
    generic_datagram_io_handler($pservice);
}
#
sub unix_datagram_service_handler
{
    my ($pservice) = @_;
    generic_datagram_service_handler($pservice);
}
#
################################################################
#
# LNB-specific io, timer, and servers
#
sub lnb_io_handler
{
    my ($pservice) = @_;
    #
    $plog->log_msg("entering lnb_io_handler() for %s\n", 
                   $pservice->{name});
    #
    my $pfh = $pservice->{fh};
    my $fileno = fileno($$pfh);
    #
    my $nr = 0;
    my $buffer = undef;
    
    while (defined($nr = sysread($$pfh, $buffer, 1024*4)) && ($nr > 0))
    {
        $plog->log_msg("nr ... <%d>\n", $nr);
        $plog->log_msg("buffer ... <%s>\n", $buffer);
        #
        my $local_buffer = unpack("H*", $buffer);
        $plog->log_msg("unpacked buffer ... <%s>\n", $local_buffer);
        #
        if ($nr > 0)
        {
             my $total_buffer = $pfh_data->get($fileno, 'total_buffer');
             $total_buffer = $total_buffer . $buffer;
             my $tblen = length($total_buffer);
             my $sohi = -1;
             my $stxi = -1;
             my $etxi = -1;
             for (my $tbi = 0; $tbi < $tblen; $tbi += 1)
             {
                 my $ch = substr($total_buffer, $tbi, 1);
                 if ($ch =~ m/^\x01/)
                 {
                     $sohi = $tbi;
                     $stxi = -1;
                     $etxi = -1;
                 }
                 elsif ($ch =~ m/^\x02/)
                 {
                     $stxi = $tbi;
                 }
                 elsif ($ch =~ m/^\x03/)
                 {
                     $etxi = $tbi;
                 }
                 #
                 if (($stxi != -1) && ($etxi != -1))
                 {
                     my $xml_start = $stxi + 1;
                     my $xml_end = $etxi - 1;
                     my $xml_length = $xml_end - $xml_start + 1;
                     my $xml_buffer = substr($total_buffer, 
                                             $xml_start, 
                                             $xml_length);
                     #
                     $pfh_data->set($fileno, 'input', $xml_buffer);
                     $pfh_data->set($fileno, 'input_length', $xml_length);
                     #
                     &{$pservice->{service_handler}}($pservice);
                     #
                     $sohi = -1;
                     $stxi = -1;
                     $etxi = -1;
                 }
             }
             #
             # reset for partially read messages.
             #
             if ($sohi != -1)
             {
                 $total_buffer = substr($total_buffer, $sohi);
                 $pfh_data->set($fileno, 'total_buffer', $total_buffer);
             }
        }
    }
    #
    if ((( ! defined($nr)) && ($! != EAGAIN)) ||
        (defined($nr) && ($nr == 0)))
    {
        #
        # EOF or some error
        #
        vec($rin, $fileno, 1) = 0;
        vec($ein, $fileno, 1) = 0;
        vec($win, $fileno, 1) = 0;
        #
        close($$pfh);
        #
        $plog->log_msg("closing socket (%d) for service %s ...\n", 
                       $fileno,
                       $pservice->{name});
        $pfh_services->deallocate($fileno);
        $pfh_data->deallocate($fileno);
    }
}
#
sub send_xml_msg
{
    my ($pservice, $xml) = @_;
    #
    my $pfh = $pservice->{fh};
    #
    my $buflen = sprintf("%06d", length($xml));
    #
    # c  ==>> SOH
    # A* ==>> XML length
    # c  ==>> STX
    # A* ==>> XML
    # c  ==>> ETX
    #
    my $buf = pack("cA*cA*c", SOH, $buflen, STX, $xml, ETX);
    #
    # len(SOH) + len(xml_length) + len(STX) + len(xml) + len(ETX)
    #
    my $nw = 1 + 6 + 1 + length($xml) + 1;
    #
    my $local_buf = unpack("H*", $buf);
    $plog->log_msg("unpacked buffer ... <%s>\n", $local_buf);
    #
    # handle partial writes.
    #
    # die $! if ( ! defined(send($$pfh, $buf, $nw)));
    for (my $ntow=$nw; 
         ($ntow > 0) &&
         defined($nw = send($$pfh, $buf, $ntow));
         $ntow -= $nw) { }
    die $! if ( ! defined($nw) );
}
#
sub lnbcvthost_service_handler
{
    my ($pservice) = @_;
    #
    my $pfh = $pservice->{fh};
    my $fileno = fileno($$pfh);
    #
    my $xml = $pfh_data->get($fileno, 'input');
    my $xml_len = $pfh_data->set($fileno, 'input_length');
    #
    $plog->log_msg("%s: xml <%s>\n", $pservice->{name}, $xml);
    #
    my $pxml = mylnbxml->new($xml, $plog);
    die "Unable to create xml parser: $!" unless (defined($pxml));
    #
    if (defined($pxml->parse()))
    {
        $plog->log_msg("Parsing succeeded.\n");
        #
        $xml = $pxml->deparse();
        if (defined($xml))
        {
            $plog->log_msg("Deparsing succeeded.\n");
            send_xml_msg($pservice, $xml);
        }
        else
        {
            $plog->log_err("ERROR: Deparsing failed.\n");
        }
    }
    else
    {
        $plog->log_err("ERROR: Parsing failed.\n");
    }
    #
    $pxml = undef;
}
#
sub lnblmhost_service_handler
{
    my ($pservice) = @_;
    #
    my $pfh = $pservice->{fh};
    my $fileno = fileno($$pfh);
    #
    my $xml = $pfh_data->get($fileno, 'input');
    my $xml_len = $pfh_data->set($fileno, 'input_length');
    #
    $plog->log_msg("%s: xml <%s>\n", $pservice->{name}, $xml);
    #
    my $pxml = mylnbxml->new($xml, $plog);
    die "Unable to create xml parser: $!" unless (defined($pxml));
    #
    if (defined($pxml->parse()))
    {
        $plog->log_msg("Parsing succeeded.\n");
        #
        $xml = $pxml->deparse();
        if (defined($xml))
        {
            $plog->log_msg("Deparsing succeeded.\n");
            send_xml_msg($pservice, $xml);
        }
        else
        {
            $plog->log_err("ERROR: Deparsing failed.\n");
        }
    }
    else
    {
        $plog->log_err("ERROR: Parsing failed.\n");
    }
    #
    $pxml = undef;
}
#
sub lnbmihost_service_handler
{
    my ($pservice) = @_;
    #
    my $pfh = $pservice->{fh};
    my $fileno = fileno($$pfh);
    #
    my $xml = $pfh_data->get($fileno, 'input');
    my $xml_len = $pfh_data->set($fileno, 'input_length');
    #
    $plog->log_msg("%s: xml <%s>\n", $pservice->{name}, $xml);
    #
    my $pxml = mylnbxml->new($xml, $plog);
    die "Unable to create xml parser: $!" unless (defined($pxml));
    #
    if (defined($pxml->parse()))
    {
        $plog->log_msg("Parsing succeeded.\n");
        #
        $xml = $pxml->deparse();
        if (defined($xml))
        {
            $plog->log_msg("Deparsing succeeded.\n");
            send_xml_msg($pservice, $xml);
        }
        else
        {
            $plog->log_err("ERROR: Deparsing failed.\n");
        }
    }
    else
    {
        $plog->log_err("ERROR: Parsing failed.\n");
    }
    #
    $pxml = undef;
}
#
sub lnbspcvthost_service_handler
{
    my ($pservice) = @_;
    #
    my $pfh = $pservice->{fh};
    my $fileno = fileno($$pfh);
    #
    my $xml = $pfh_data->get($fileno, 'input');
    my $xml_len = $pfh_data->set($fileno, 'input_length');
    #
    $plog->log_msg("%s: xml <%s>\n", $pservice->{name}, $xml);
    #
    my $pxml = mylnbxml->new($xml, $plog);
    die "Unable to create xml parser: $!" unless (defined($pxml));
    #
    if (defined($pxml->parse()))
    {
        $plog->log_msg("Parsing succeeded.\n");
        #
        $xml = $pxml->deparse();
        if (defined($xml))
        {
            $plog->log_msg("Deparsing succeeded.\n");
            send_xml_msg($pservice, $xml);
        }
        else
        {
            $plog->log_err("ERROR: Deparsing failed.\n");
        }
    }
    else
    {
        $plog->log_err("ERROR: Parsing failed.\n");
    }
    #
    $pxml = undef;
}
#
sub lnbspmihost_service_handler
{
    my ($pservice) = @_;
    #
    my $pfh = $pservice->{fh};
    my $fileno = fileno($$pfh);
    #
    my $xml = $pfh_data->get($fileno, 'input');
    my $xml_len = $pfh_data->set($fileno, 'input_length');
    #
    $plog->log_msg("%s: xml <%s>\n", $pservice->{name}, $xml);
    #
    my $pxml = mylnbxml->new($xml, $plog);
    die "Unable to create xml parser: $!" unless (defined($pxml));
    #
    if (defined($pxml->parse()))
    {
        $plog->log_msg("Parsing succeeded.\n");
        #
        $xml = $pxml->deparse();
        if (defined($xml))
        {
            $plog->log_msg("Deparsing succeeded.\n");
            send_xml_msg($pservice, $xml);
        }
        else
        {
            $plog->log_err("ERROR: Deparsing failed.\n");
        }
    }
    else
    {
        $plog->log_err("ERROR: Parsing failed.\n");
    }
    #
    $pxml = undef;
}
#
sub lnbcvthost_timer_handler
{
    my ($pservice) = @_;
}
#
sub lnblmhost_timer_handler
{
    my ($pservice) = @_;
}
#
sub lnbmihost_timer_handler
{
    my ($pservice) = @_;
}
#
sub lnbspcvthost_timer_handler
{
    my ($pservice) = @_;
}
#
sub lnbspmihost_timer_handler
{
    my ($pservice) = @_;
}
#
################################################################
#
# create services
#
sub function_defined
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
#
sub add_stdin_to_services
{
    my $fno = fileno(STDIN);
    #
    $pfh_services->set($fno, {
        name => "STDIN",
        type => TTY_STREAM(),
        io_handler => \&stdin_handler,
        timer_handler => \&stdin_timer_handler,
    });
    #
    $pfh_data->reallocate($fno);
    #
    $plog->log_msg("Adding STDIN service ...\n");
    $plog->log_msg("name ... %s type ... %s\n", 
                  $pfh_services->get($fno, 'name'),
                  $pfh_services->get($fno, 'type'));
    #
    vec($rin, fileno(STDIN), 1) = 1;
}
#
sub get_handler
{
    my ($handler) = @_;
    #
    if (function_defined($handler) == TRUE)
    {
        # turn off strict so we can convert name to function.
        no strict 'refs';
        return \&{$handler};
    }
    else
    {
        $plog->log_err("Function %s does NOT EXIST.\n", $handler);
        return undef
    }
}
#
sub create_socket_stream
{
    my ($pservice) = @_;
    #
    $plog->log_msg("Creating stream socket for %s.\n", $pservice->{name});
    #
    # my $fh = FileHandle->new;
    my $fh = undef;
    socket($fh, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
    setsockopt($fh, SOL_SOCKET, SO_REUSEADDR, 1);
    #
    my $ipaddr = gethostbyname($pservice->{host_name});
    defined($ipaddr) or die "gethostbyname: $!";
    #
    my $port = undef;
    if (exists($pservice->{service}) && 
        defined($pservice->{service}))
    {
        # get port from services file
        $port = getservbyname($pservice->{service}, 'tcp') or
            die "Can't get port for service $pservice->{service}: $!";
        $plog->log_msg("getservbyname($pservice->{service}, 'tcp') port = $port\n");
        $pservice->{port} = $port;
    }
    else
    {
        $port = $pservice->{port};
        $plog->log_msg("config file port = $port\n");
    }
    my $paddr = sockaddr_in($port, $ipaddr);
    defined($paddr) or die "sockaddr_in: $!";
    #
    bind($fh, $paddr) or die "bind error for $pservice->{name}: $!";
    listen($fh, SOMAXCONN) or die "listen: $!";
    #
    $plog->log_vmin("File Handle is ... $fh, %d\n", fileno($fh));
    #
    $pservice->{fh} = \$fh;
    #
    # check for required handlers
    #
    my $handler = $pservice->{io_handler};
    $pservice->{io_handler} = get_handler($handler);
    if ( ! defined($pservice->{io_handler}))
    {
        $plog->log_err("Function %s does NOT EXIST.\n", $handler);
        return FALSE;
    }
    #
    $handler = $pservice->{service_handler};
    $pservice->{service_handler} = get_handler($handler);
    if ( ! defined($pservice->{service_handler}))
    {
        $plog->log_err("Function %s does NOT EXIST.\n", $handler);
        return FALSE;
    }
    #
    $handler = $pservice->{client_io_handler};
    $pservice->{client_io_handler} = get_handler($handler);
    if ( ! defined($pservice->{client_io_handler}))
    {
        $plog->log_err("Function %s does NOT EXIST.\n", $handler);
        return FALSE;
    }
    #
    $handler = $pservice->{client_service_handler};
    $pservice->{client_service_handler} = get_handler($handler);
    if ( ! defined($pservice->{client_service_handler}))
    {
        $plog->log_err("Function %s does NOT EXIST.\n", $handler);
        return FALSE;
    }
    #
    # check for optional handlers
    #
    $handler = $pservice->{timer_handler};
    if (defined($handler))
    {
        $pservice->{timer_handler} = get_handler($handler);
        if ( ! defined($pservice->{timer_handler}))
        {
            $plog->log_err("Function %s does NOT EXIST.\n", $handler);
            return FALSE;
        }
    }
    #
    $handler = $pservice->{ctor};
    if (defined($handler))
    {
        $pservice->{ctor} = get_handler($handler);
        if ( ! defined($pservice->{ctor}))
        {
            $plog->log_err("Function %s does NOT EXIST.\n", $handler);
            return FALSE;
        }
    }
    #
    $handler = $pservice->{client_timer_handler};
    if (defined($handler))
    {
        $pservice->{client_timer_handler} = get_handler($handler);
        if ( ! defined($pservice->{client_timer_handler}))
        {
            $plog->log_err("Function %s does NOT EXIST.\n", $handler);
            return FALSE;
        }
    }
    #
    $handler = $pservice->{client_ctor};
    if (defined($handler))
    {
        $pservice->{client_ctor} = get_handler($handler);
        if ( ! defined($pservice->{client_ctor}))
        {
            $plog->log_err("Function %s does NOT EXIST.\n", $handler);
            return FALSE;
        }
    }
    #
    return SUCCESS;
}
#
sub create_socket_dgram
{
    my ($pservice) = @_;
    #
    $plog->log_msg("Creating dgram socket for %s.\n", $pservice->{name});
    #
    # my $fh = FileHandle->new;
    my $fh = undef;
    socket($fh, PF_INET, SOCK_DGRAM, getprotobyname('udp'));
    setsockopt($fh, SOL_SOCKET, SO_REUSEADDR, 1);
    #
    my $ipaddr = gethostbyname($pservice->{host_name});
    defined($ipaddr) or die "gethostbyname: $!";
    #
    my $port = undef;
    if (exists($pservice->{service}) && 
        defined($pservice->{service}))
    {
        # get port from services file
        $port = getservbyname($pservice->{service}, 'udp') or
            die "Can't get port for service $pservice->{service}: $!";
        $plog->log_msg("getservbyname($pservice->{service}, 'udp') port = $port\n");
    }
    else
    {
        $port = $pservice->{port};
        $plog->log_msg("config file port = $port\n");
    }
    my $paddr = sockaddr_in($port, $ipaddr);
    defined($paddr) or die "sockaddr_in: $!";
    #
    bind($fh, $paddr) or die "bind: $!";
    #
    $plog->log_vmin("File Handle is ... $fh, %d\n", fileno($fh));
    #
    $pservice->{fh} = \$fh;
    #
    # check for required handlers
    #
    my $handler = $pservice->{io_handler};
    $pservice->{io_handler} = get_handler($handler);
    if ( ! defined($pservice->{io_handler}))
    {
        $plog->log_err("Function %s does NOT EXIST.\n", $handler);
        return FALSE;
    }
    #
    $handler = $pservice->{service_handler};
    $pservice->{service_handler} = get_handler($handler);
    if ( ! defined($pservice->{service_handler}))
    {
        $plog->log_err("Function %s does NOT EXIST.\n", $handler);
        return FALSE;
    }
    #
    # check for optional handlers
    #
    $handler = $pservice->{timer_handler};
    if (defined($handler))
    {
        $pservice->{timer_handler} = get_handler($handler);
        if ( ! defined($pservice->{timer_handler}))
        {
            $plog->log_err("Function %s does NOT EXIST.\n", $handler);
            return FALSE;
        }
    }
    #
    $handler = $pservice->{ctor};
    if (defined($handler))
    {
        $pservice->{ctor} = get_handler($handler);
        if ( ! defined($pservice->{ctor}))
        {
            $plog->log_err("Function %s does NOT EXIST.\n", $handler);
            return FALSE;
        }
    }
    #
    return SUCCESS;
}
#
sub create_unix_stream
{
    my ($pservice) = @_;
    #
    $plog->log_msg("Creating stream unix pipe for %s.\n", $pservice->{name});
    #
    # my $fh = FileHandle->new;
    my $fh = undef;
    socket($fh, PF_UNIX, SOCK_STREAM, 0);
    #
    unlink($pservice->{file_name});
    #
    $plog->log_msg("unix stream file = %s\n", $pservice->{file_name});
    my $paddr = sockaddr_un($pservice->{file_name});
    defined($paddr) or die "sockaddr_un: $!";
    #
    bind($fh, $paddr) or die "bind: $!";
    listen($fh, SOMAXCONN) or die "listen: $!";
    #
    $plog->log_vmin("File Handle is ... $fh, %d\n", fileno($fh));
    #
    $pservice->{fh} = \$fh;
    #
    # check for required handlers
    #
    my $handler = $pservice->{io_handler};
    $pservice->{io_handler} = get_handler($handler);
    if ( ! defined($pservice->{io_handler}))
    {
        $plog->log_err("Function %s does NOT EXIST.\n", $handler);
        return FALSE;
    }
    #
    $handler = $pservice->{service_handler};
    $pservice->{service_handler} = get_handler($handler);
    if ( ! defined($pservice->{service_handler}))
    {
        $plog->log_err("Function %s does NOT EXIST.\n", $handler);
        return FALSE;
    }
    #
    $handler = $pservice->{client_io_handler};
    $pservice->{client_io_handler} = get_handler($handler);
    if ( ! defined($pservice->{client_io_handler}))
    {
        $plog->log_err("Function %s does NOT EXIST.\n", $handler);
        return FALSE;
    }
    #
    $handler = $pservice->{client_service_handler};
    $pservice->{client_service_handler} = get_handler($handler);
    if ( ! defined($pservice->{client_service_handler}))
    {
        $plog->log_err("Function %s does NOT EXIST.\n", $handler);
        return FALSE;
    }
    #
    # check for optional handlers
    #
    $handler = $pservice->{timer_handler};
    if (defined($handler))
    {
        $pservice->{timer_handler} = get_handler($handler);
        if ( ! defined($pservice->{timer_handler}))
        {
            $plog->log_err("Function %s does NOT EXIST.\n", $handler);
            return FALSE;
        }
    }
    #
    $handler = $pservice->{ctor};
    if (defined($handler))
    {
        $pservice->{ctor} = get_handler($handler);
        if ( ! defined($pservice->{ctor}))
        {
            $plog->log_err("Function %s does NOT EXIST.\n", $handler);
            return FALSE;
        }
    }
    #
    $handler = $pservice->{client_timer_handler};
    if (defined($handler))
    {
        $pservice->{client_timer_handler} = get_handler($handler);
        if ( ! defined($pservice->{client_timer_handler}))
        {
            $plog->log_err("Function %s does NOT EXIST.\n", $handler);
            return FALSE;
        }
    }
    #
    $handler = $pservice->{client_ctor};
    if (defined($handler))
    {
        $pservice->{client_ctor} = get_handler($handler);
        if ( ! defined($pservice->{client_ctor}))
        {
            $plog->log_err("Function %s does NOT EXIST.\n", $handler);
            return FALSE;
        }
    }
    #
    return SUCCESS;
}
#
sub create_unix_dgram
{
    my ($pservice) = @_;
    #
    $plog->log_msg("Creating dgram unix pipe for %s.\n", $pservice->{name});
    #
    # my $fh = FileHandle->new;
    my $fh = undef;
    socket($fh, PF_UNIX, SOCK_DGRAM, 0);
    #
    unlink($pservice->{file_name});
    #
    $plog->log_msg("unix datagram file = %s\n", $pservice->{file_name});
    my $paddr = sockaddr_un($pservice->{file_name});
    defined($paddr) or die "sockaddr_un: $!";
    #
    bind($fh, $paddr) or die "bind: $!";
    #
    $plog->log_vmin("File Handle is ... $fh, %d\n", fileno($fh));
    #
    $pservice->{fh} = \$fh;
    #
    # check for required handlers
    #
    my $handler = $pservice->{io_handler};
    $pservice->{io_handler} = get_handler($handler);
    if ( ! defined($pservice->{io_handler}))
    {
        $plog->log_err("Function %s does NOT EXIST.\n", $handler);
        return FALSE;
    }
    #
    $handler = $pservice->{service_handler};
    $pservice->{service_handler} = get_handler($handler);
    if ( ! defined($pservice->{service_handler}))
    {
        $plog->log_err("Function %s does NOT EXIST.\n", $handler);
        return FALSE;
    }
    #
    # check for optional handlers
    #
    $handler = $pservice->{timer_handler};
    if (defined($handler))
    {
        $pservice->{timer_handler} = get_handler($handler);
        if ( ! defined($pservice->{timer_handler}))
        {
            $plog->log_err("Function %s does NOT EXIST.\n", $handler);
            return FALSE;
        }
    }
    #
    $handler = $pservice->{ctor};
    if (defined($handler))
    {
        $pservice->{ctor} = get_handler($handler);
        if ( ! defined($pservice->{ctor}))
        {
            $plog->log_err("Function %s does NOT EXIST.\n", $handler);
            return FALSE;
        }
    }
    #
    return SUCCESS;
}
#
sub create_server_connections
{
    my $piter = $pservices->iterator();
    while (defined(my $service = $piter->()))
    {
        $plog->log_msg("Creating server conection for %s ...\n", $service);
        #
        my $type = $pservices->get($service, 'type');
        die "ERROR: connection type $type is unknown: $!" 
            unless (exists($create_connection{$type}));
        my $status = &{$create_connection{$type}}($pservices->get($service));
        if ($status == SUCCESS)
        {
            my $pfh = $pservices->get($service, 'fh');
            my $fileno = fileno($$pfh);
            $plog->log_msg("Successfully create server socket/pipe for %s (%d)\n", 
                           $service, $fileno);
            $pfh_services->set($fileno, $pservices->get($service));
            $pfh_data->reallocate($fileno);
            #
            # call ctor if it exists.
            #
            my $ctor = $pservices->get($service, 'ctor');
            if (defined($ctor))
            {
                $status = &{$ctor}($pservices->get($service));
            }
        }
        else
        {
            $plog->log_err("Failed to create server socket/pipe for %s\n", $service);
            return FAIL;
        }
    }
    #
    return SUCCESS;
}
#
################################################################
#
# event loop for timers and i/o (via select)
#
sub set_io_nonblock
{
    my $piter = $pservices->iterator();
    while (defined(my $service = $piter->()))
    {
        my $pfh = $pservices->get($service, 'fh');
        fcntl($$pfh, F_SETFL, O_NONBLOCK);
    }
}
#
sub start_timer
{
    my ($fileno, $delta, $label) = @_;
    #
    my $timerid = int(rand(1000000000));
    #
    if ($delta <= 0)
    {
        $plog->log_err("Timer length is zero for %s. Skipping it.\n", $fileno);
        return;
    }
    #
    $plog->log_vmin("starttimer: " .
                    "fileno=${fileno} " .
                    "label=${label} " .
                    "delta=${delta} " .
                    "id=$timerid ");
    #
    my $ptimer = mytimer->new($fileno, $delta, $timerid, $label);
    #
    $plog->log_vmin("fileno = $ptimer->{fileno} " .
                    "delta = $ptimer->{delta} " .
                    "expire = $ptimer->{expire} " .
                    "id = $ptimer->{id} " .
                    "label = $ptimer->{label} ");
    #
    $pq->enqueue($ptimer);
}
#
sub run_event_loop
{
    #
    # mark all file handles as non-blocking
    #
    set_io_nonblock();
    #
    my $psit = $pservices->iterator();
    while (defined(my $service = $psit->()))
    {
        my $pfh = $pservices->get($service, 'fh');
        vec($rin, fileno($$pfh), 1) = 1;
    }
    #
    # enter event loop
    #
    my $sanity_time = 5;
    #
    $plog->log_msg("Start event loop ...\n");
    #
    my $mydelta = 0;
    my $start_time = time();
    my $current_time = $start_time;
    my $previous_time = 0;
    #
    while ($event_loop_done == FALSE)
    {
        #
        # save current time as the last time we did anything.
        #
        $previous_time = $current_time;
        #
        if ($pq->is_empty())
        {
            start_timer(fileno(STDIN),
                        $sanity_time, 
                        "sanity-timer");
        }
        #
        my $ptimer = undef;
        die "Empty timer queue: $!" unless ($pq->front(\$ptimer) == 1);
        #
        $mydelta = $ptimer->{expire} - $current_time;
        $mydelta = 0 if ($mydelta < 0);
        #
        my ($nf, $timeleft) = select($rout=$rin, 
                                     $wout=$win, 
                                     $eout=$ein, 
                                     $mydelta);
        #
        # update current timers
        #
        $current_time = time();
        #
        if ($timeleft <= 0)
        {
            $plog->log_vmin("Time expired ...\n");
            #
            $ptimer = undef;
            while ($pq->dequeue(\$ptimer) != 0)
            {
                if ($ptimer->{expire} > $current_time)
                {
                    $pq->enqueue($ptimer);
                    last;
                }
                #
                my $fileno = $ptimer->{fileno};
                my $pservice = $pfh_services->get($fileno);
                #
                &{$pservice->{timer_handler}}($ptimer, $pservice);
                $ptimer = undef;
            }
        }
        elsif ($nf > 0)
        {
            $plog->log_msg("NF, TIMELEFT ... (%d,%d)\n", $nf, $timeleft);
            my $pfhit = $pfh_services->iterator();
            while (defined(my $fileno = $pfhit->()))
            {
                my $pfh = $pfh_services->get($fileno, 'fh');
                my $pservice = $pfh_services->get($fileno);
                #
                if (vec($eout, $fileno, 1))
                {
                    #
                    # EOF or some error
                    #
                    vec($rin, $fileno, 1) = 0;
                    vec($ein, $fileno, 1) = 0;
                    vec($win, $fileno, 1) = 0;
                    #
                    close($$pfh);
                    #
                    $plog->log_msg("closing socket (%d) for service %s ...\n", 
                                   $fileno,
                                   $pservice->{name});
                    $pfh_services->deallocate($fileno);
                }
                elsif (vec($rout, $fileno, 1))
                {
                    #
                    # ready for a read
                    #
                    $plog->log_msg("input available for %s ...\n", $pservice->{name});
                    #
                    # call handler
                    #
                    &{$pservice->{io_handler}}($pservice);
                }
            }             
        }
    }
    #
    $plog->log_msg("Event-loop done ...\n");
    return SUCCESS;
}
#
################################################################
#
# start execution
#
$plog->disable_stdout_buffering();
#
my %opts;
if (getopts('?hwWv:l:', \%opts) != 1)
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
    elsif ($opt eq 'w')
    {
	$plog->verbose(MINVERBOSE);
    }
    elsif ($opt eq 'W')
    {
        $plog->verbose(MIDVERBOSE);
    }
    elsif ($opt eq 'v')
    {
        if (!defined($plog->verbose($opts{$opt})))
        {
            $plog->log_msg("ERROR: Invalid verbose level: $opts{$opt}\n");
            usage($cmd);
            exit 2;
        }
    }
    elsif ($opt eq 'l')
    {
        $plog->logfile($opts{$opt});
        $plog->log_msg("Log File: %s\n", $opts{$opt});
    }
}
#
# check if config file was given.
#
if (scalar(@ARGV) == 0)
{
    #
    # use default config file.
    #
    $plog->log_msg("Using default config file: %s\n", $default_cfg_file);
    if (read_cfg_file($default_cfg_file) != SUCCESS)
    {
        $plog->log_err_exit("read_cfg_file failed. Done.\n");
    }
}
else
{
    #
    # read in config files and start up services.
    #
    foreach my $cfg_file (@ARGV)
    {
        $plog->log_msg("Reading config file %s ...\n", $cfg_file);
        if (read_cfg_file($cfg_file) != SUCCESS)
        {
            $plog->log_err_exit("read_cfg_file failed. Done.\n");
        }
    }
}
#
# create server sockets or pipes as needed.
#
if (create_server_connections() != SUCCESS)
{
    $plog->log_err_exit("create_server_connections failed. Done.\n");
}
#
# monitor stdin for i/o with user.
#
add_stdin_to_services();
#
# event loop to handle connections, etc.
#
if (run_event_loop() != SUCCESS)
{
    $plog->log_err_exit("run_event_loop failed. Done.\n");
}
#
$plog->log_msg("All is well that ends well.\n");
#
exit 0;

__DATA__


