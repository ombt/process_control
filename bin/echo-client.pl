#!/usr/bin/perl -w

use strict;
use IO::Socket;

my $server = IO::Socket::INET->new(Proto => "tcp",
                                   PeerPort => 59001,
                                   PeerAddr => "localhost",
                                   Timeout => 2000)
             || die "failed to connect\n";
for (1..100) {
    print $server $_ . "\n";
    my $res;
    $server->recv($res, 70000);
    print $res;
}

exit 0;

