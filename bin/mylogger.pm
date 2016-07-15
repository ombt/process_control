# logging module
#
package mylogger;
#
use strict;
use warnings;
#
use FileHandle;
use base qw( Exporter );
#
our @EXPORT = qw (
    NOVERBOSE
    MINVERBOSE
    MIDVERBOSE
    MAXVERBOSE
);
#
# verbose levels
#
use constant NOVERBOSE => 0;
use constant MINVERBOSE => 1;
use constant MIDVERBOSE => 2;
use constant MAXVERBOSE => 3;
#
our %verbose_levels =
(
    off => NOVERBOSE(),
    min => MINVERBOSE(),
    mid => MIDVERBOSE(),
    max => MAXVERBOSE()
);
#
# create a logger
#
sub new
{
    my $class = shift;
    my $self = {};
    #
    if (scalar(@_) > 0)
    {
        local *FH;
        $self->{logfile} = shift;
        open(FH, '>', $self->{logfile}) or die $!;
        FH->autoflush(0);
        $self->{log_fh} = *FH;
    }
    else
    {
        $self->{logfile} = undef;
        $self->{log_fh} = *STDOUT;
    }
    $self->{verbose} = NOVERBOSE();
    #
    bless $self, $class;
    #
    return($self);
}
#
sub logfile
{
    my $self = shift;
    if (@_)
    {
        local *FH;
        if (defined($self->{logfile}))
        {
            my $log_fh = $self->{log_fh};
            close($log_fh);
        }
        $self->{logfile} = shift;
        open(FH, '>', $self->{logfile}) or die $!;
        FH->autoflush(0);
        $self->{log_fh} = *FH;
    }
    else
    {
        if (defined($self->{logfile}))
        {
            my $log_fh = $self->{log_fh};
            close($log_fh);
        }
        $self->{logfile} = undef;
        $self->{log_fh} = *STDOUT;
    }
}
#
sub verbose
{
    my $self = shift;
    #
    if (@_)
    {
        my $verbose = shift;
        if ($verbose =~ m/^[0123]$/)
        {
            $self->{verbose} = $verbose;
        }
        elsif (exists($verbose_levels{$verbose}))
        {
            $self->{verbose} = $verbose_levels{$verbose};
        }
        else
        {
            $self->{verbose} = undef;
        }
    }
    #
    return($self->{verbose});
}
#
sub log_fh
{
    my $self = shift;
    #
    return($self->{log_fh});
}
#
sub log_base
{
    my $self = shift;
    my $fmt = shift;
    my @args = @_;
    #
    $fmt = "\n%d: " . $fmt;
    #
    my @data = caller(1);
    #
    my $pkg = $data[0];
    my $fnm = $data[1];
    my $lnno = $data[2];
    my $subr = $data[3];
    #
    my $log_fh = $self->{log_fh};
    printf $log_fh $fmt, $lnno, @args;
}
#
sub log_msg
{
    my $self = shift;
    $self->log_base(@_);
}
#
sub log_err_exit
{
    my $self = shift;
    my $fmt = shift;
    my @args = @_;
    $self->log_base("ERROR EXIT: " . $fmt, @args);
    exit 2;
}
#
sub log_err
{
    my $self = shift;
    my $fmt = shift;
    my @args = @_;
    $self->log_base("ERROR: " . $fmt, @args);
}
#
sub log_warn
{
    my $self = shift;
    my $fmt = shift;
    my @args = @_;
    $self->log_base("WARNING: " . $fmt, @args);
}
#
sub log_vmsg
{
    my $self = shift;
    my $vlvl = shift;
    my $fmt = shift;
    my @args = @_;
    #
    $fmt = "\n%d: " . $fmt;
    #
    my @data = caller(1);
    #
    my $pkg = $data[0];
    my $fnm = $data[1];
    my $lnno = $data[2];
    my $subr = $data[3];
    #
    my $log_fh = $self->{log_fh};
    printf $log_fh $fmt, $lnno, @args
        if ($self->{verbose} >= $vlvl);
}
#
sub log_vmin
{
    my $self = shift;
    $self->log_vmsg(MINVERBOSE, @_);
}
#
sub log_vmid
{
    my $self = shift;
    $self->log_vmsg(MIDVERBOSE, @_);
}
#
sub log_vmax
{
    my $self = shift;
    $self->log_vmsg(MAXVERBOSE, @_);
}
#
sub disable_stdout_buffering
{
    my $self = shift;
    $|++;
}
#
# exit with success
#
1;
