#!/usr/bin/perl -w
#
use strict;
#
my $binpath;
#
BEGIN {
    use File::Basename;
    #
    $binpath = dirname($0);
    $binpath = "." if ($binpath eq "");
}
#
use lib $binpath;
#
use MyConstants;
use MyPQueue;
use MyTimer;
use MyLogger;
use MyTaskData;
#
printf "TRUE is ... %d\n", MyConstants->TRUE();
printf "FALSE is ... %d\n", MyConstants->FALSE();
printf "SUCCESS is ... %d\n", MyConstants->SUCCESS();
printf "FAIL is ... %d\n", MyConstants->FAIL();
printf "NOVERBOSE is ... %d\n", MyLogger->NOVERBOSE();
printf "MINVERBOSE is ... %d\n", MyLogger->MINVERBOSE();
printf "MIDVERBOSE is ... %d\n", MyLogger->MIDVERBOSE();
printf "MAXVERBOSE is ... %d\n", MyLogger->MAXVERBOSE();
#
printf "TRUE is ... %d\n", TRUE();
printf "FALSE is ... %d\n", FALSE();
printf "SUCCESS is ... %d\n", SUCCESS();
printf "FAIL is ... %d\n", FAIL();
printf "NOVERBOSE is ... %d\n", NOVERBOSE();
printf "MINVERBOSE is ... %d\n", MINVERBOSE();
printf "MIDVERBOSE is ... %d\n", MIDVERBOSE();
printf "MAXVERBOSE is ... %d\n", MAXVERBOSE();
#
my $pq = MyPQueue->new();
my $tmr = MyTimer->new(1, 10, 1111, 'hello');
my $logger = MyLogger->new();
my $tdata = MyTaskData->new();
#
my $logger2 = MyLogger->new();
$logger2->logfile("/tmp/shit");
#
$logger->log_msg("write any message ...\n\n");
$logger2->log_msg("write any message ...\n\n");
#
$logger->log_msg("setting verbose to ... %d\n", $logger->verbose(NOVERBOSE));
$logger->log_vmin("vmin ... %d\n", $logger->verbose());
$logger->log_vmid("vmid ... %d\n", $logger->verbose());
$logger->log_vmax("vmax ... %d\n", $logger->verbose());
$logger2->log_msg("setting verbose to ... %d\n", $logger2->verbose(NOVERBOSE));
$logger2->log_vmin("vmin ... %d\n", $logger2->verbose());
$logger2->log_vmid("vmid ... %d\n", $logger2->verbose());
$logger2->log_vmax("vmax ... %d\n", $logger2->verbose());
#
$logger->log_msg("setting verbose to ... %d\n", $logger->verbose(MINVERBOSE));
$logger->log_vmin("vmin ... %d\n", $logger->verbose());
$logger->log_vmid("vmid ... %d\n", $logger->verbose());
$logger->log_vmax("vmax ... %d\n", $logger->verbose());
$logger2->log_msg("setting verbose to ... %d\n", $logger2->verbose(MINVERBOSE));
$logger2->log_vmin("vmin ... %d\n", $logger2->verbose());
$logger2->log_vmid("vmid ... %d\n", $logger2->verbose());
$logger2->log_vmax("vmax ... %d\n", $logger2->verbose());
#
$logger->log_msg("setting verbose to ... %d\n", $logger->verbose(MIDVERBOSE));
$logger->log_vmin("vmin ... %d\n", $logger->verbose());
$logger->log_vmid("vmid ... %d\n", $logger->verbose());
$logger->log_vmax("vmax ... %d\n", $logger->verbose());
$logger2->log_msg("setting verbose to ... %d\n", $logger2->verbose(MIDVERBOSE));
$logger2->log_vmin("vmin ... %d\n", $logger2->verbose());
$logger2->log_vmid("vmid ... %d\n", $logger2->verbose());
$logger2->log_vmax("vmax ... %d\n", $logger2->verbose());
#
$logger->log_msg("setting verbose to ... %d\n", $logger->verbose(MAXVERBOSE));
$logger->log_vmin("vmin ... %d\n", $logger->verbose());
$logger->log_vmid("vmid ... %d\n", $logger->verbose());
$logger->log_vmax("vmax ... %d\n", $logger->verbose());
$logger2->log_msg("setting verbose to ... %d\n", $logger2->verbose(MAXVERBOSE));
$logger2->log_vmin("vmin ... %d\n", $logger2->verbose());
$logger2->log_vmid("vmid ... %d\n", $logger2->verbose());
$logger2->log_vmax("vmax ... %d\n", $logger2->verbose());
#
$logger->log_msg("1 exists ... <%s>\n", $tdata->exists(1));
if ($tdata->exists(1) == TRUE)
{
    $logger->log_msg("1 does exist\n");
}
else
{
    $logger->log_msg("1 does NOT exist\n");
}
$logger->log_msg("1 eatme exists ... <%s>\n", $tdata->exists(1,"eatme"));
if ($tdata->exists(1,"eatme") == TRUE)
{
    $logger->log_msg("1 eatme does exist\n");
}
else
{
    $logger->log_msg("1 eatme does NOT exist\n");
}
#
$tdata->set(1,"eatme", "NOPE");
#
$logger->log_msg("exists ... <%s>\n", $tdata->exists(1,"eatme"));
if ($tdata->exists(1,"eatme") == TRUE)
{
    $logger->log_msg("eatme does exist ... %s\n",
                     $tdata->get(1,"eatme"));
}
else
{
    $logger->log_msg("eatme STILL does NOT exist\n");
}
#
$logger->log_msg("reallocate ... \n");
$tdata->reallocate(1);
#
$logger->log_msg("exists ... <%s>\n", $tdata->exists(1,"eatme"));
if ($tdata->exists(1,"eatme") == TRUE)
{
    $logger->log_msg("eatme does exist\n");
}
else
{
    $logger->log_msg("eatme does NOT exist\n");
}
#
$tdata->set(1,"eatme", "NOPE");
#
$logger->log_msg("exists ... <%s>\n", $tdata->exists(1,"eatme"));
if ($tdata->exists(1,"eatme") == TRUE)
{
    $logger->log_msg("eatme does exist ... %s\n",
                     $tdata->get(1,"eatme"));
}
else
{
    $logger->log_msg("eatme STILL does NOT exist\n");
}
#
$logger->log_msg("clear data ... \n");
$tdata->clear();
#
my $piter = $tdata->iterator();
#
$logger->log_msg("start iterate over empty data object ... \n");
while (defined(my $key = $piter->()))
{
    $logger->log_msg("item is ... %s\n", $key);
    foreach my $key2 (sort keys(%{$tdata->get($key)}))
    {
        $logger->log_msg("item id is ... %s => %s\n", 
                         $key2, $tdata->get($key, $key2));
    }
}
$logger->log_msg("end iterate over empty data object ... \n");
#
$tdata->set(1,"eatme", "NOPE");
$tdata->set(1,"eatme2", "NOPE2");
$tdata->set(1,"eatme3", "NOPE3");
$tdata->set(1,"eatme4", "NOPE4");
$tdata->set(2,"eatme", "NOPE");
$tdata->set(2,"eatme2", "NOPE2");
$tdata->set(2,"eatme3", "NOPE3");
$tdata->set(2,"eatme4", "NOPE4");
$tdata->set(3,"eatme", "NOPE");
$tdata->set(3,"eatme2", "NOPE2");
$tdata->set(3,"eatme3", "NOPE3");
$tdata->set(3,"eatme4", "NOPE4");
#
$piter = $tdata->iterator();
#
$logger->log_msg("start iterate over NON-empty data object ... \n");
while (defined(my $key = $piter->()))
{
    $logger->log_msg("item is ... %s\n", $key);
    foreach my $key2 (sort keys(%{$tdata->get($key)}))
    {
        $logger->log_msg("item id is ... %s => %s\n", 
                         $key2, $tdata->get($key, $key2));
    }
}
$logger->log_msg("end iterate over NON-empty data object ... \n");
#
exit 0;
