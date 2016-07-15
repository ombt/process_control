#!/usr/bin/perl -w

use strict;
use threads;
use IO::Socket::INET;

sub start_thread {
   my ($client, $client_num) = @_;
   print "thread created for client $client_num\n";
   while (1) {
       my $req;
       $client->recv($req, 700000);
       return if ($req eq ""); 
       print $client $req;
   }
   return;
}

$| ++;

my $listener = IO::Socket::INET->new(LocalPort => 20000,
                                     Listen => 5,
                                     Reuse => 1) || 
             die "Cannot create socket\n";

my $client;
my $client_num = 0;
while (1) {
   $client = $listener->accept;
   threads->create(\&start_thread, $client, ++ $client_num);
}

exit 0;
