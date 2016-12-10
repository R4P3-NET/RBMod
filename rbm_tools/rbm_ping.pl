#!/usr/bin/perl
# ,============================================================================.
# |             ____     __                             __                     |
# |            /\  _`\  /\ \       /'\_/`\             /\ \                    |
# |            \ \ \L\ \\ \ \____ /\      \     ___    \_\ \                   |
# |             \ \ ,  / \ \ '__`\\ \ \__\ \   / __`\  /'_` \                  |
# |              \ \ \\ \ \ \ \L\ \\ \ \_/\ \ /\ \L\ \/\ \L\ \                 |
# |               \ \_\ \_\\ \_,__/ \ \_\\ \_\\ \____/\ \___,_\                |
# |                \/_/\/ / \/___/   \/_/ \/_/ \/___/  \/__,_ /                |
# |                                                                            |
# |                   RbMod (Responsive Bot Modification)                      |
# |             Copyright (C) 2013, Matthew Weyrich - Scor9ioN                 |
# |                       (admin@rbmod.presension.com)                         |
# |                           rbmod.presension.com                             |
# |                                  v3.2.3                                    |
# `============================================================================`
use 5.10.0;
use strict;
use warnings;

my ($DBID,$CLID,$CLIP,$OSType,$ip2,$ip3,$ip4) = @ARGV;
my $results;
my $ret = &Rbm_PingIt($CLIP);
$ret = &Rbm_PingIt($ip2) unless $ret;
$ret = &Rbm_PingIt($ip3) unless $ret;
$ret = &Rbm_PingIt($ip4) unless $ret;

if ($ret) {
    $ret =~ s/\.\d+//go;
    $results = $ret;
#    say 'FIXING TO > '.$results;
}
else {
#   Try traceroute for ping statistics now!
    my ($newpid,@address_cnt,$lastpingablehop,$secondpingablehop,
            $address,$hops);
    my $EndOfTrace = 0;
    $SIG{CHLD} = 'IGNORE';
    if ($OSType !~ /Win/oi) {
        if ($OSType =~ /bsd/oi) {
            $newpid = open(FROM, "-|", 'traceroute -n -m 31 '.$CLIP) or die $!;
        }
        else {
            $newpid = open(FROM, "-|", 'traceroute -I -4 -n -d -m 31 -N 40 '.$CLIP)
                or die $!;
        }
    }
    else {
        $newpid = open(FROM, "-|", 'tracert -d -h 31 -w 2 '.$CLIP) or die $!;
    }
    while ( <FROM> ) {
        chomp;
        if ( / (\S+) ms\s+\d+/o ) {
            $results = $1;
            $results =~ s/\.\d+$//go if $results;
        }
        elsif ( /\*\s+\*\s+\*|Request timed/i ) {
            ++$EndOfTrace;
            last if $EndOfTrace > 5;
        }
    }
    close(FROM);
    kill('TERM',$newpid);
}

if (defined $results) {
#    $results = 0.0 if $results < 1;
#    say $results;
    open (my $CACHE, ">>",'rbm_stored/rbm_cache.cf');
    flock($CACHE, 2);
    syswrite $CACHE, 'DBID='.$DBID.' CLID='.$CLID.' CURRENTPING='.$results.'|';
    flock($CACHE, 8);
    close $CACHE;
}

exit 0;

sub Rbm_PingIt {
    my $CLIP = shift;
    my $results;
    my $time = time;
    if ($OSType !~ /Win/oi) {
        my $newpid;
        $SIG{CHLD} = 'IGNORE';
        if ($OSType =~ /bsd/oi) {
            $newpid = open(FROM, "-|", 'ping '.$CLIP) or die $!;
        }
        else {
            $newpid = open(FROM, "-|", 'ping -w 2 '.$CLIP) or die $!;
        }
        my $cnt = 0;
        while (<FROM>) {
            chomp;
            ++$cnt if /\d+ bytes from/i;
            ($results) = $_ =~ /time\=(\d+)[\.\d+]? ms/go;
            last if $cnt > 1;
        }
        close FROM;
        kill('TERM',$newpid);
    }
    else {
        my $newpid = open(FROM, "-|", 'ping -n 2 '.$CLIP) or die $!;
        my $cnt = 0;
        while (<FROM>) {
            chomp;
            ++$cnt if /Reply from/i;
            ($results) = $_ =~ /time[<>=](\d+)ms/g;
            last if $cnt > 1;
        }
        close FROM;
        kill('TERM',$newpid);
    }
    return $results;
}
