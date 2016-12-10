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

my ($DBID,$CLID,$CLIP,$OSType,$SET_Method,$SET_Method2,$SET_TraceDual) = @ARGV;
my ($Hopscnt_ref,$Hopscnt_ref2,$lastpingablehop,$secondpingablehop,
        $thirdpingablehop,$lastpingablehop2,$secondpingablehop2,
        $thirdpingablehop2,$statistics_ref);

$SET_Method  =~ s/TCP/T/oi;
$SET_Method  =~ s/ICMP/I/oi;
$SET_Method2 =~ s/TCP/T/oi;
$SET_Method2 =~ s/ICMP/I/oi;
#&$sub_log("INFO  \t- Traceroute      \t- Starting first trace on "
#        .$online_ref->{$CLID}{'Nickname'}.'...');
($Hopscnt_ref,$lastpingablehop,$secondpingablehop,$thirdpingablehop,
        $statistics_ref) = &Rbm_TraceMe($CLIP,$SET_Method,$OSType,$CLID);

if ( $SET_TraceDual ne 0 ) {
#    &$sub_log("INFO  \t- Traceroute      \t- Issuing second trace on "
#            .$online_ref->{$CLID}{'Nickname'}.'...');
    ($Hopscnt_ref2,$lastpingablehop2,$secondpingablehop2,$thirdpingablehop2,
            $statistics_ref) = &Rbm_TraceMe($CLIP,$SET_Method2,$OSType,$CLID);
    if ($$Hopscnt_ref2 > $$Hopscnt_ref) {
        $$Hopscnt_ref = $$Hopscnt_ref2;
 #       &$sub_log("INFO  \t- Traceroute     \t- "
#                .$online_ref->{$CLID}{'Nickname'}
#                .'\'s second trace prevailed with a higher count.');
    }
}
my ($PingAddress,$PingAddress2,$PingAddress3) = (0,0,0);
$PingAddress     = $lastpingablehop    if $lastpingablehop;
$PingAddress     = $secondpingablehop  if $secondpingablehop;
$PingAddress2    = $lastpingablehop2   if $lastpingablehop2;
$PingAddress2    = $secondpingablehop2 if $secondpingablehop2;
$PingAddress3    = $thirdpingablehop   if $thirdpingablehop;
$PingAddress3    = $thirdpingablehop2  if $thirdpingablehop2;
my $traceResults = join '\\n',@$statistics_ref;
$traceResults    =~ s/ /\\t/goi;
open(my $CACHE, ">>",'rbm_stored/rbm_cache.cf') or exit 0;
flock($CACHE, 2);
syswrite $CACHE, 'DBID='.$DBID.' CLID='.$CLID
        .' HPS='.$$Hopscnt_ref.' HPR='.time.' PATH='.$traceResults
        .' PNG='.$PingAddress.' PNG2='.$PingAddress2.' PNG3='.$PingAddress3.'|';
flock($CACHE, 8);
close $CACHE;
exit 0;

sub Rbm_TraceMe {
    my ($CLIP,$Method,$SET_OSType,$CLID) = @_;
    my ($lastpingablehop,$secondpingablehop,$thirdpingablehop,$hops,$newpid,
            @address_cnt,%results,$address,$TmpHops) = (0,0,0,1);
    $| = 1;
    $SIG{CHLD} = 'DEFAULT';
    if ($SET_OSType !~ /Win/oi) {
        if ($SET_OSType =~ /BSD/oi) {
            if ($Method =~ /T/o) {
                $newpid = open(FROM, "-|", 'traceroute -n -m 31 '.$CLIP) or die $!;
            }
            else {
                $newpid = open(FROM, "-|", 'traceroute -I -n -m 31 '.$CLIP) or die $!;
            }
        }
        else {
            $newpid = open(FROM, "-|", 'traceroute -'.$Method.' -4 -n -d -m 31 -N 12 '.$CLIP)
                or die $!;
        }
    }
    else {
        $newpid = open(FROM, "-|", 'tracert -d -h 31 -w 2 '.$CLIP)
            or die $!;
    }
    while ( <FROM> ) {
        chomp;
        if (/^[\s]*?(\d{1,2})\s+(.*?)$/) {
            $TmpHops   = $1;
            ($address) = $_ =~ /(\d+\.\d+\.\d+\.\d+)/o;
            if ( (defined $address_cnt[-1] && defined $address_cnt[-2]
                && defined $address_cnt[-3] && defined $address_cnt[-4]
                && defined $address_cnt[-5] && defined $address_cnt[-6])
                && ( ( defined $address && $results{$hops - 1} && $results{$hops - 1} =~ /$address/
                && exists $results{$hops - 2} && $results{$hops - 2} =~ /$address/
                && exists $results{$hops - 3} && $results{$hops - 3} =~ /$address/
                && exists $results{$hops - 4} && $results{$hops - 4} =~ /$address/
                && exists $results{$hops - 5} && $results{$hops - 5} =~ /$address/ )
                || ( !$address && $address_cnt[-1] =~ /\* \* \*|Request timed|\!H/oi
                && $address_cnt[-2] =~ /\* \* \*|Request timed|\!H/oi
                && $address_cnt[-3] =~ /\* \* \*|Request timed|\!H/oi
                && $address_cnt[-4] =~ /\* \* \*|Request timed|\!H/oi
                && $address_cnt[-5] =~ /\* \* \*|Request timed|\!H/oi
                && $address_cnt[-6] =~ /\* \* \*|Request timed|\!H/oi  ) )) {
                pop(@address_cnt) if $address_cnt[-1] && $address_cnt[-1] =~ /\* \* \*|Request timed|\!H/oi;
                pop(@address_cnt) if $address_cnt[-2] && $address_cnt[-2] =~ /\* \* \*|Request timed|\!H/oi;
                pop(@address_cnt) if $address_cnt[-3] && $address_cnt[-3] =~ /\* \* \*|Request timed|\!H/oi;
                pop(@address_cnt) if $address_cnt[-4] && $address_cnt[-4] =~ /\* \* \*|Request timed|\!H/oi;
                pop(@address_cnt) if $address_cnt[-5] && $address_cnt[-5] =~ /\* \* \*|Request timed|\!H/oi;
                pop(@address_cnt) if $address_cnt[-6] && $address_cnt[-6] =~ /\* \* \*|Request timed|\!H/oi;
                last;
            }
            elsif ( $address ) {
               $thirdpingablehop = $secondpingablehop;
               $secondpingablehop = $lastpingablehop;
               $lastpingablehop = $address;
               $hops = sprintf("%.2d", $TmpHops);
               $results{$hops} = $hops;
            }
            push(@address_cnt,$_);
        }
    }
    close(FROM);
    kill('TERM',$newpid);
    $hops =~ s/^0//goi if defined $hops;
    $hops = 1 unless defined $hops;
    ++$hops if (defined $lastpingablehop && $CLIP ne $lastpingablehop);
    return (\$hops,$lastpingablehop,$secondpingablehop,$thirdpingablehop,\@address_cnt);
}
