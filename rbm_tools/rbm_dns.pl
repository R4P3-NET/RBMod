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

my ($CLIP,$DBID,$CLID) = @ARGV;

my $results = `nslookup $CLIP 2>&1`;
my $cache;
#&$sub_log("INFO \t- Reverse DNS      \t- Forked thread and Looking up ".$online_ref->{$CLID}{'Nickname'}.' ('.$CLIP.')');
if ( $results =~ /name = (\S+)/oi ) {
    $cache = $1;
#    &$sub_log("INFO  \t- Reverse DNS       \t- Found ".$online_ref->{$CLID}{'Nickname'}.'\'s DNS of '.$cache);
}
elsif ( $results =~ /Name\:\s+(\S+)/oi ) {
    ($cache) = $1;
#    &$sub_log("INFO  \t- Reverse DNS       \t- Found ".$online_ref->{$CLID}{'Nickname'}.'\'s DNS of '.$cache);
}
if ( $cache ) {
    open(my $CACHE, ">>",'rbm_stored/rbm_cache.cf') or die "ERROR\t- Reverse DNS   \t- Couldn\'t Load rbm_cache.cf: ".$!;
    flock($CACHE, 2);
    print $CACHE 'DBID='.$DBID.' CLID='.$CLID.' DNS='.$cache.'|';
    flock($CACHE, 8);
    close $CACHE;
}

exit 0;

