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
use Time::HiRes qw( sleep );

my ($CLIP,$DBID,$CLID,$Server) = @ARGV;
my $reversedIP = join('.', reverse(split(/\./,$CLIP)));
my @servers = split /\,/,$Server;
push @servers,$Server unless @servers;
my ($address,$read,$results,$cache);
foreach $address (@servers) {
    ($results,$cache) = undef;
    $address =~ s/^\s+//;
    $address =~ s/\s+$//;
    $results = `nslookup $reversedIP.$address 2>&1`;
    if ( $results and $results =~ /Address\:\s+(127\.0\.0\.[2-9]|127\.0\.0\.1[0-2])/oi ) {
#       &$sub_log("WARN  \t- RBL Lookup       \t- Found " .$online_ref->{$CLID}{'Nickname'}. '\'s Blacklisted on '.$Server.'!');
        open(my $CACHE, ">>",'rbm_stored/rbm_cache.cf') or die "ERROR \t- RBL Lookup   \t- Couldn\'t Load rbm_cache.cf: ".$!;
        flock($CACHE, 2);
        print $CACHE 'DBID='.$DBID.' CLID='.$CLID.' RBL='.$CLIP.' SRV='.$address.'|';
        flock($CACHE, 8);
        close $CACHE;
        $read = 1;
        last;
    }
    sleep 0.75;
}
if (!$read) {
    $read = 1;
#       &$sub_log("INFO \t- RBL Lookup      \t- " . $online_ref->{$CLID}{'Nickname'} . '\'s IP passed the online blacklist scan.');
    open(my $CACHE, ">>",'rbm_stored/rbm_cache.cf') or die "ERROR \t- RBL Lookup   \t- Couldn\'t Load rbm_cache.cf: ".$!;
    flock($CACHE, 2);
    print $CACHE 'DBID='.$DBID.' CLID='.$CLID.' RBL=1 SRV=1|';
    flock($CACHE, 8);
    close $CACHE;
}
exit 0;
