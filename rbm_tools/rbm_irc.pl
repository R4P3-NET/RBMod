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
use IO::Socket();
use Time::HiRes qw ( sleep );

my ($label,$server,$port,$nick,$nickalt,$login,$chans,$Ops,$Voiced) = @ARGV;

my @Channels = split /\,/o,$chans;
my $sockIRC = new IO::Socket::INET(
                                PeerAddr  => $server,
                                PeerPort  => $port,
                                Proto     => 'tcp',
                                Keepalive => 1,
                                Timeout   => 20,
                                Blocking  => 0,
                               ) or die "Can't connect!\n";
$sockIRC->autoflush(1);
# Log on to the server.
syswrite $sockIRC, "NICK $nick\r\n";
syswrite $sockIRC, "USER $login 8 * :RbMod For TeamSpeak3\r\n";
my ($input,$bytes_read,$Cache_Data,$CACHE,$ts3data);
# Read lines from the server until it tells us we have connected.
while ($input = <$sockIRC>) {
    # Check the numerical responses from the server.
#    say $input;
    if ($input =~ /004/o) {
#        &$sub_log("INFO \t- IRC Bot         \t- IRC Bot logged in as "
#                .$nick, 1);
        last;
    }
    elsif ($input =~ /433/o) {
        syswrite $sockIRC, 'NICK '.$nickalt."\r\n";
        $nick = $nickalt;
        next;
    }
}

# Join the channel(s).
foreach my $channel (@Channels) {
    $channel = '#'.$channel if $channel !~ /\#/o;
    syswrite $sockIRC, 'JOIN '.$channel."\r\n";
#    &$sub_log("INFO \t- IRC Bot         \t- Joining IRC channel "
#            .$channel, 1);
}

while (1) {
    ($input,$ts3data) = undef;
#   Read TS3 IRC Cache Socket
    $Cache_Data = &CheckIRCCache;
#   Read From IRC Socket
    $bytes_read = sysread($sockIRC, $input, 500*1024);
    if ( defined $bytes_read && $bytes_read != 0 ) {
#       say $input;
        if ($input =~ /^PING(.*)$/oi) {
            syswrite $sockIRC, 'PONG '.$1."\r\n";
        }
        else {
            if ($input =~ /[\:](\S+)\![\~]\S+\@(\S+) JOIN \:\#(\S+)/o) {
                my $cmd = &Rbm_IRC_Automated($1,$2,$3,$Ops,$Voiced);
                syswrite $sockIRC, $cmd."\r\n" if $cmd;
            }
            $input = &procIRCChat($input);
            if ($input) {
                open($CACHE, ">>",'rbm_stored/rbm_cache.cf')
                        or say 'Problem reading from cache file';
                flock($CACHE, 2);
                syswrite $CACHE, 'IRC=('.$label.') '.$input.'|';
                flock($CACHE, 8);
                close $CACHE;
            }
        }
    }
#   Write To IRC Socket
    if ($Cache_Data) {
        syswrite $sockIRC, $Cache_Data."\r\n";
    }
    $ts3data = &CheckTS3Cache;
    if ($ts3data && $ts3data =~ /msg\=(.*?) invokerid\=\d+ invokername=(.*?) invoker/o) {
        my ($msg,$name) = ($1,$2);
        my $chan;
        foreach $chan (@Channels) {
            syswrite $sockIRC, 'PRIVMSG '.$chan.' :<'.$name.'> '.$msg."\r\n";
        }
#        open($CACHE, ">>",'rbm_stored/rbm_cache.cf')
#                or say 'Problem reading from cache file';
#        flock($CACHE, 2);
#        syswrite $CACHE, 'TS3='.$ts3data.'|';
#        flock($CACHE, 8);
#        close $CACHE;
    }
    sleep 0.5;
}

sub Rbm_IRC_Automated {
    my ($CLNick,$CLIP,$CLChan,$Ops,$Voiced) = @_;
    my @AutoOIPs = split /\,/,$Ops;
    my @AutoVIPs = split /\,/,$Voiced;
    my @AutoOP = grep(/^$CLIP$/, @AutoOIPs);
    my @AutoVoice = grep(/^$CLIP$/, @AutoVIPs);
    my $IP;
    foreach $IP (@AutoOP) {
        return 'MODE #'.$CLChan.' +o '.$CLNick;
    }
    foreach $IP (@AutoVoice) {
        return 'MODE #'.$CLChan.' +v '.$CLNick;
    }
    return undef;
}

sub procIRCChat {
    my $input = shift;
    $input =~ s/[\|\r\n]+//gi;
    my ($nickname,$identd) = $input =~ m/\:(\S+)\![\~]?(\S+)\s/gco;
#    $input =~ s/\:(\S+)\!\S+\s/\[B\]$1\[\/B\] /go;
    $input =~ s/\:(\S+)\![\~]?(\S+)\s/\[B\]$1\[\/B\] /go;
    my ($channel,$data) = $input =~ m/PRIVMSG \#(\S+) \:(.*?)$/go;
    return $input unless $nickname and $channel and $data;
    my $cleaned = '#'.$channel.' <[B]'.$nickname.'[/B]> [COLOR=BLACK]'
            .$data.'[/COLOR]';
    return $cleaned;
}

sub CheckTS3Cache {
    my $CacheFile = 'rbm_stored/rbm_TS3cache.cf';
    return unless -e $CacheFile;
    open(my $CACHE, "<".$CacheFile) or say $!;
    flock($CACHE, 2);
    my $Cached = <$CACHE>;
    flock($CACHE, 8);
    close $CACHE;
    unlink $CacheFile;

    my ($data,$build);
    my @raw = $Cached =~ m/ts3=(.*?)\|/i if $Cached;
    foreach $data (@raw) {
        $data =~ s/\\s/ /go;
        $build .= $data.'\n';
    }
    return $build if $build;
    return;
}

sub CheckIRCCache {
    my $CacheFile = 'rbm_stored/rbm_irc_cache.cf';
    return unless -e $CacheFile;
    open(my $CACHE, "<".$CacheFile) or say $!;
    flock($CACHE, 2);
    my $Cached = <$CACHE>;
    flock($CACHE, 8);
    close $CACHE;
    unlink $CacheFile;
    my ($data) = $Cached =~ m/irc=(.*?)\|/i if $Cached;
    if ($data) {
        $data =~ s/\\s/ /go;
        return $data;
    }
    return;
}

exit 0;

