#!/usr/bin/perl --

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
# |                                  v3.2.4                                    |
# `============================================================================`
#            This product includes GeoLite data created by MaxMind,
#                    available from http://www.maxmind.com

use lib './rbm_packages';
use 5.10.0;
use strict;
use warnings;
use rbm_parent;
use Time::HiRes qw( sleep );

$| = 1;
my ($cnt,$online_ref,%allrooms,%groups,$clientlist_ref,$channellist_ref,$Reboot,
        $DBReload,$Pid,$KB) = 0;
my ($rooms_ref, $settings_ref, $FFChans, $badwords_ref, $randomwords_ref,
        $BotCLIDs_ref,$FFClients_ref) = rbm_parent::Rbm_Bootup(\%groups);
local $SIG{'INT'} = \&rbm_parent::Rbm_Cleanup if $^O !~ /Win/io;
local $SIG{'BREAK'} = \&rbm_parent::Rbm_Cleanup if $^O =~ /Win/io;

$Pid = fork();
if (!defined $Pid) {
    say 'Resources not avilable to fork child process!';
    exit 0;
}
elsif ($Pid == 0) {
    close STDIN;
    use rbm_features;
    my ($sub_cache,$sub_clinfo,$sub_clwrite,$sub_clread,$sub_query,$sub_partMsg,
            $sub_monitor,$sub_kalive,$sub_watch,$sub_clean,$bytes2mbs,
            $sub_traffic,$sub_ping,$sub_ranking,$sub_chdel,$sub_chflood,
            $sub_nickpro,$sub_dynban,$sub_chlang,$sub_rss,$sub_list,$slowit,$Tik,$Tx,$Rx,$paddedA,
            $paddedB,$UserLeft) = (\&rbm_parent::Rbm_CheckCache,
            \&rbm_parent::Rbm_ClientInfo,\&rbm_parent::Rbm_ClientInfoWriteFF,
            \&rbm_parent::Rbm_ClientInfoLoadFF,\&rbm_parent::Rbm_TS3Query,
            \&rbm_parent::Rbm_PartMsgs,\&rbm_parent::Rbm_Monitor,
            \&rbm_parent::Rbm_KeepAlive,\&rbm_parent::Rbm_Watch,
            \&rbm_parent::Rbm_Clean,\&rbm_parent::Rbm_BytesToMBytes,
            \&rbm_features::Rbm_Traffic,\&rbm_features::Rbm_Ping,
            \&rbm_features::Rbm_Ranking,\&rbm_features::Rbm_ChannelDelete,
            \&rbm_features::Rbm_ChannelFlood,\&rbm_features::Rbm_NickProtect,
            \&rbm_features::Rbm_DynamicBanner,
            \&rbm_features::Rbm_ChanLanguage,
            \&rbm_features::Rbm_RSSParse,
            \&rbm_features::Rbm_ListSubscribe,
            time - 2,time);
    while(1) {
        if ($cnt >= 5) {
#            say 'reading cache - time = '.time;
            ($settings_ref,$Reboot,$DBReload) = &$sub_cache; # (RbMod) - Cache
            $cnt = 0;
        }
        if ($slowit <= (time - 1)) {
            # (RbMod) - Query Channel List
            $channellist_ref = &$sub_query('channellist',
                    'cid=\d+.*?channel_name=.*?error id=0 msg=ok');
            # (RbMod) - Query Client List
            $clientlist_ref  = &$sub_query('clientlist',
                    'cid=\d+ client_database_id=\d+.*?error id=0 msg=ok');
            if ($DBReload) {
                &$sub_clread(1);
            }
            elsif ($Reboot) {
                $online_ref = ();
                &$sub_clwrite();
            }
            unless ($clientlist_ref || $channellist_ref) {
                sleep 0.5;
                next;
            }
            # (RbMod) - Check For User Disconnections
            $UserLeft = &$sub_monitor(\%groups,$clientlist_ref);
            if ($UserLeft) {
                $clientlist_ref = undef;
                next;
            }
            # (RbMod) - Query Individual Clients (ClientInfo) via Client List
            ($online_ref,$badwords_ref) = &$sub_clinfo($clientlist_ref,\%groups,
                    $channellist_ref );
            $slowit = time;
            if ($online_ref) {
                # [Feature] - Traffic Meter
                &$sub_traffic($online_ref,$settings_ref,\%groups);
                # [Feature] - Military Ranking
                &$sub_ranking($online_ref,\%groups,$settings_ref);
                # [Feature] - Scan over Channels for matching badwords.
                $badwords_ref = &$sub_chlang($online_ref,$channellist_ref,
                        $badwords_ref,$settings_ref,\%allrooms,$randomwords_ref);
                # [Feature] - Check Flat File for dormant channels.
                &$sub_chdel($online_ref,$rooms_ref,$settings_ref,$FFChans,
                        $channellist_ref);
                # [Feature] - Check Channel Flood Protection
                &$sub_chflood($online_ref,$settings_ref,\%groups,$FFClients_ref);
                # [Feature] - Nickname Protection
                &$sub_nickpro($online_ref,$settings_ref);
                # [Feature] - Dynamic Host Banners
                &$sub_dynban($online_ref,$settings_ref);
                # [Feature] - Random Parting Messages
                &$sub_partMsg($settings_ref);
                # [Feature] - RSS Feeds
                &$sub_rss($online_ref,$settings_ref);
                # [Feature] - Online List of RbMod servers
                &$sub_list($settings_ref);
            }
            ($settings_ref,$Reboot,$DBReload) = &$sub_cache; # (RbMod) - Cache
#            say 'reading cache - time = '.time;
            if ($Tik < (time - 60)) { # (RbMod) - Socket(s) Keep-Alive
                for (@$BotCLIDs_ref) {
                    &$sub_kalive($_);
                }
                $Tik = time;
            }
            if ($rbm_parent::Debug == 1) { # (RbMod) - Debug to console
                $Tx = &$sub_clean(&$bytes2mbs($rbm_parent::MODsent ),1,1);
                $Rx = &$sub_clean(&$bytes2mbs($rbm_parent::MODreceived ),1,1);
                $paddedA = sprintf("%-*s",18,'<Tx: '.$$Tx);
                $paddedB = sprintf("%-*s",18,'Rx: '.$$Rx);
                print "\r".$paddedA.$paddedB.'> ';
                $rbm_parent::MODreceived = 0;
                $rbm_parent::MODsent = 0;
            }
        }
        &$sub_watch; # (RbMod) - Watch socket for client !triggers
        sleep 0.1;
        ++$cnt;
    }
    exit 0;
}
else {
    sleep 2;
    my $sub_stdn = \&rbm_parent::Rbm_STDINCapture;
    while (defined($KB = <STDIN>)) {
        &$sub_stdn($KB,$settings_ref,$Pid);
    }
    waitpid($Pid, 0);
}
exit 0;
