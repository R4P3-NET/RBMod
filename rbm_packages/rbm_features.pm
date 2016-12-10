package rbm_features;

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
use File::stat qw(:FIELDS);
use Time::localtime;
use Time::HiRes qw( sleep );
use Encode;

my ($nl,$sub_Weather,$sub_log,$sub_send,$sub_proctime,$sub_cleantext,
    $sub_logformat,$sub_query,$sub_countries,$sub_TxRx,%RSSCache,
    %ActiveChannels,$message) = ("\n",\&rbm_parent::Rbm_WeatherLookup,
    \&rbm_parent::Rbm_Log,\&rbm_parent::Rbm_TSSend,
    \&rbm_parent::Rbm_ProcessTime,\&rbm_parent::Rbm_Clean,
    \&rbm_parent::Rbm_LogFormat,\&rbm_parent::Rbm_TS3Query,\&Rbm_CCodes,
    \&Rbm_TxRxCalc);
my %ActiveGameRooms;
our %Features;

sub Check4Update {
    my $vcheck = 'rbm_stored/rbm_vcheck.cf';
    my $onfile = 'RbMod v';
    my $CurrentVersion = $rbm_parent::Version;
    my $url;
#   Check Last update interval
    unless (-e $vcheck) {
        unless(open FILE, '>'.$vcheck) {
           say "Unable to create $vcheck";
           return;
        }
    }
    close FILE;
    open (VCHECK, "<".$vcheck) || say 'Can\'t find '.$vcheck && return;
    my $vinfo = <VCHECK>;
    close VCHECK;
    my ($LastUpdate) = $vinfo =~ /time=(\d+)/o if $vinfo;
    say $nl."\t".('#' x 100);
    say "\tChecking online for latest release version...";
    if (!$LastUpdate or ($LastUpdate < (time - 28800))) {
        open (VCHECK, ">".$vcheck) || say "\t\tCan\'t find ".$vcheck && return;
        print VCHECK 'time='. time;
        close VCHECK;
        $url = rbm_parent::get('http://rbmod.presension.com/check4update/version.nfo');
    }
    else {
        if (-e $onfile) {
            say "\t\'\/".$onfile.'\' has already been downloaded.';
        }
        else {
            say "\tYou\'re currently running the latest release\. \(v".$CurrentVersion.')';
        }
        say "\t".'#' x 100,$nl;
        return;
    }
#   Proceed to go online and check release information against ours.
    unless ($url) {
        say "\tCouldn\'t retrieve online version information from http:\/\/rbmod.presension.com...";
        return;
    }
    my ($OnlineVersion) = $url =~ /Current Version: (\S+)/oi;
    $onfile = $onfile.$OnlineVersion.'.zip' if $OnlineVersion;
    if ($OnlineVersion and $OnlineVersion ne $CurrentVersion) {
        say "\tYour version \(v".$CurrentVersion.') is out of date! ';
        if (-e $onfile) {
            say "\t\'\/".$onfile.'\' has already been downloaded.';
            say "\t".'#' x 100,$nl;
            return;
        }
        print "\tDownload now\? \(Yes\/No\) ";
        my $userinput = <STDIN>;
        chomp($userinput);
        if ($userinput !~ /^N/oi) {
            $url = 'http://rbmod.presension.com/'.$onfile;
            my $status = rbm_parent::getstore($url, $onfile);
            die "\tError $status on $url" unless is_success($status);
            say "\tDownload of version ".$OnlineVersion.' complete!';
            print "\tContinue booting previous version ".$CurrentVersion.'? (Yes/No): ';
            $userinput = <STDIN>;
            if ($userinput !~ /^N/oi) {
                return;
            }
            else {
                say "\tCheck RbMod directory for your new download.";
                say "\t".'#' x 100,$nl;
                exit 0;
            }
        }
        else {
            say "\tPlease download the latest release version ".$OnlineVersion." from...\n\t\t"
                    .'http://addons.teamspeak.com/directory/tools/miscellaneous/%D0%AFbMod-Perl-Modification.html';
        }
    }
    else {
        say "\tYou\'re currently running the latest release v".$CurrentVersion.'.';
    }
    say "\t".'#' x 100,$nl;
}

sub Rbm_ListSubscribe {
    my $settings_ref = shift;
    return unless $rbm_parent::Booted;
    return if $settings_ref->{'Subscribe_To_Rb_Online_Server_List_On'} ne 1;
    return if ($settings_ref->{'Subscribe_To_Rb_Online_Server_List_Polled'} || 0)
        > (time - $settings_ref->{'Subscribe_To_Rb_Online_Server_List_Interval'});
    $settings_ref->{'Subscribe_To_Rb_Online_Server_List_Polled'} = time;
    my $url = rbm_parent::get('http://rbmod.presension.com/servers?DOnline='
        .$rbm_parent::TotalClients.'&DAddress='
        .$settings_ref->{'Subscribe_To_Rb_Online_Server_List_Address_Displayed'}
        .'&DVersion='.$rbm_parent::Version
        .'&DName='.$settings_ref->{'ServName'}
        .'&TS3Version='.$settings_ref->{'TS3Version'});
}

sub Rbm_RSSParse {
    my ($online_ref,$settings_ref) = @_;
    return if $settings_ref->{'RSS_Feed_On'} eq 0;
    return if ($settings_ref->{'RSS_Feed_TimeStamp'} || 0)
            > (time - $settings_ref->{'RSS_Feed_Interval'});
    $settings_ref->{'RSS_Feed_TimeStamp'} = time;
    if ($rbm_parent::OSType =~ /Win/io) {
        system(1,$^X,"./rbm_tools/rbm_rss.pl", $settings_ref->{'RSS_Feed_URL'});
    }
    else {
        if (fork() == 0) {
            exec($^X,"./rbm_tools/rbm_rss.pl", $settings_ref->{'RSS_Feed_URL'});
            exit 0;
        }
    }
}

sub Rbm_ChannelDelete {
    my ($online_ref,$rooms_ref,$settings_ref,$FFChans,$channellist_ref) = @_;
    return if $settings_ref->{'Channel_Delete_Dormant_On'} eq 0;
    return unless $channellist_ref;
#   Check Update Interval
    if ( ($settings_ref->{'Channel_Delete_Dormant_TimeStamp'} || 0)
        > (time - ($settings_ref->{'Channel_Delete_Dormant_Interval'} || 60)) ){
        return;
    }
#    say 'Channel Cleaner';
    $settings_ref->{'Channel_Delete_Dormant_TimeStamp'} = time;
#   Build string from live hash for FF DB storage.
    my (@LiveRooms) = $$channellist_ref =~ /cid=(\d+)/go;
    my $BuildString = '';
    my (@CleanNonExists,@SubTree,@queue,@ExemptRanges,@ChannelTree,$Toast,
            $Sub_Channels,$Used,$UsedBy,$UsedTime,$LowID,$HighID,$found,
            $ChanName,$RoomName,$RoomUsedBy,$time,$ap,$day,$date,$timestamp,
            $ID,@ExemptIDs,$chan,$subchan,$Room,$LiveRoom,$Missing,$Range,
            $skip);
    foreach $Room ( keys %$rooms_ref ) {
        next if !$Room || ($Room && $Room eq 'Length');
        if ($$channellist_ref !~ /cid=$Room /) {
            push(@CleanNonExists, $Room);
            next;
        }
        $UsedTime = $rooms_ref->{$Room}{'TimeUsed'} || time;
        if ($UsedTime < (time - ($settings_ref->{'Channel_Delete_Dormant_Requirements'} || 0))) {
#           Check for Children Channels and mark for deletion.
            $rooms_ref->{$Room}{'RoomTree'} = $Room.',';
            &Rbm_CheckChildren($Room,$Room,$channellist_ref,$rooms_ref);
        }
    }
    $Room = undef;
#   Quickly cleanup channel hash with deleted / removed channels.
    foreach $Missing ( @CleanNonExists ) {
        delete $rooms_ref->{$Missing};
    }
#   Load in LIVE channels
    foreach $LiveRoom (@LiveRooms) {
        ($ChanName) = $$channellist_ref =~ /cid=$LiveRoom pid=\d+ channel_order=\d+ channel_name=(\S+) total/;
        $rooms_ref->{$LiveRoom}{'TimeUsed'} = time unless exists $rooms_ref->{$LiveRoom}{'TimeUsed'};
        $rooms_ref->{$LiveRoom}{'UsedBy'} = '' unless exists $rooms_ref->{$LiveRoom}{'UsedBy'};
        $rooms_ref->{$LiveRoom}{'Name'} = $ChanName;
    }
    @ExemptRanges = ($settings_ref->{'Channel_Delete_Dormant_Exempt_IDs'} || '') =~ /\[(.+?)\]/go;
    @ExemptIDs = split /\,/, ($settings_ref->{'Channel_Delete_Dormant_Exempt_IDs'} || '');
#   Check Exempt Id's first
    foreach $Room (keys %$rooms_ref) {
        next if !$Room or $Room !~ /\d/o;
        $found = undef;
        if (exists $rooms_ref->{$Room}{'RoomTree'}) {
            @ChannelTree = split(/\,/,$rooms_ref->{$Room}{'RoomTree'});
            foreach $chan (@ChannelTree) {
                next if $chan eq '' or $chan == 0;
    #           Search exemptions for simple ID entries.
                foreach $ID (@ExemptIDs) {
                    next if $ID !~ /^\d+$/o;
                    if ($ID == $chan) {
                        $found = 1;
                        last;
                    }
                }
                last if defined $found;
    #           Search exemptions between lowest ID and heighest ID.
                foreach $Range (@ExemptRanges) {
                    ($LowID,$HighID) = split /\-/,$Range;
                    if ( $chan >= $LowID && $chan <= $HighID) {
                        $found = 1;
                        last;
                    }
                }
            }
        }
        else {
            foreach $ID (@ExemptIDs) {
                next if $ID !~ /^\d+$/o;
                if ($ID == $Room) {
                    $found = 1;
                    last;
                }
            }
            unless (defined $found) {
                foreach $Range (@ExemptRanges) {
                    ($LowID,$HighID) = split /\-/,$Range;
                    if ( $Room >= $LowID && $Room <= $HighID) {
                        $found = 1;
                        last;
                    }
                }
            }
        }
        push(@queue,$Room) unless defined $found;
    }
    $Room = undef;
#   Now check against time requirements.
    foreach $chan (@queue) {
        ($Toast,$skip) = undef;
        ($Sub_Channels) = $rooms_ref->{$chan}{'RoomTree'} =~ /$chan\,(.*?)$/
            if exists $rooms_ref->{$chan}{'RoomTree'};
        if ( $Sub_Channels ) {
            @SubTree = split /\,/,$Sub_Channels;
            foreach $subchan (@SubTree) {
                next if $chan == 0;
                if (exists $rooms_ref->{$subchan}{'TimeUsed'}
                        && $rooms_ref->{$subchan}{'TimeUsed'} <= (time -
                        $settings_ref->{'Channel_Delete_Dormant_Requirements'}) ) {
                    last;
                }
                else {
                    $skip = 1;
                    if (exists $rooms_ref->{$subchan}{'TimeUsed'}
                            && $rooms_ref->{$subchan}{'TimeUsed'} >= (time -
                            $settings_ref->{'Channel_Delete_Dormant_Trash_Icon_Requirements'})
                            && exists $rooms_ref->{$subchan}{'SoonToast'}) {
                        delete $rooms_ref->{$subchan}{'SoonToast'};
                        &$sub_send('channeledit cid='.$subchan.' channel_description=Active');
                        &$sub_send('channeldelperm cid='.$subchan.' permsid=i_icon_id' );
                    }
                }
            }
        }
        if ($rooms_ref->{$chan}{'TimeUsed'} < (time - $settings_ref->{'Channel_Delete_Dormant_Trash_Icon_Requirements'})
                && !exists $rooms_ref->{$chan}{'SoonToast'} && !$Sub_Channels && !$skip) {
            $rooms_ref->{$chan}{'SoonToast'} = 1;
            ($time,$ap,$day,$date) = &$sub_proctime((time
                    + $settings_ref->{'Channel_Delete_Dormant_Requirements'})
                    - $settings_ref->{'Channel_Delete_Dormant_Trash_Icon_Requirements'});
            $timestamp = &$sub_logformat( join('',($$time.'\s'.$$ap.'\s'.$$day)), 1);
            &$sub_send('channeledit cid='.$chan
                .' channel_description=Channel\smarked\sto\sbe\sdeleted\sat\s'.$$timestamp);
            &$sub_send('channeladdperm cid='.$chan
                .' permsid=i_icon_id permvalue=301694691 permskip=0 permnegated=0');

            next
        }
        next if $skip;
        if ($rooms_ref->{$chan}{'TimeUsed'} < (time - ($settings_ref->{'Channel_Delete_Dormant_Requirements'} || 0))) {
            $Toast = 1;
        }
        elsif (exists $rooms_ref->{$chan}{'TimeUsed'}
                && $rooms_ref->{$chan}{'TimeUsed'} >= (time -
                $settings_ref->{'Channel_Delete_Dormant_Trash_Icon_Requirements'})
                && exists $rooms_ref->{$chan}{'SoonToast'}) {
            delete $rooms_ref->{$chan}{'SoonToast'};
            &$sub_send('channeledit cid='.$chan.' channel_description=Active');
            &$sub_send('channeldelperm cid='.$chan.' permsid=i_icon_id' );
        }
        next unless defined $Toast;
        $RoomName = $rooms_ref->{$chan}{'Name'} || '\s';
        $RoomUsedBy = $rooms_ref->{$chan}{'UsedBy'} || '';
        ($time,$ap,$day,$date) = &$sub_proctime($rooms_ref->{$chan}{'TimeUsed'});
        $timestamp = &$sub_logformat(join('',($$time.'\s'.$$ap.'\s'.$$day)), 1);
#       Delete Room
        my $results_ref = &$sub_query( 'channeldelete cid='.$chan.' force=0',
                'error id=0 msg=ok');
        if (defined $results_ref) {
            &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]Dormant\sChannel[/COLOR][/B][COLOR=NAVY]\s-\sRemoving\s[/COLOR][COLOR=BLUE][B]\s'
                .$RoomName.'[/B][/COLOR][COLOR=NAVY]\s('.$chan.')[/COLOR]' );
            if ( $RoomUsedBy && $RoomUsedBy ne 'Null' && $RoomUsedBy =~ /\S+/o ) {
                $$timestamp =~ s/\\s$//o;
                &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[B]'
                    .$RoomUsedBy.'\s[/B][COLOR=NAVY]used\sthis\schannel\slast\sat\s'.$$timestamp.'.[/COLOR]' );
            }
            &$sub_log("INFO  \t- Channel Delete     \t- Found Room ID ".$chan
                .' dormant since '.$$timestamp.' Last user: '.$RoomUsedBy);
            delete $rooms_ref->{$chan};
        }
        sleep 0.05;
    }
#   Load Hash
    foreach $Room ( keys %$rooms_ref ) {
        $Used = $rooms_ref->{$Room}{'TimeUsed'} || time;
        $UsedBy = $rooms_ref->{$Room}{'UsedBy'} || 'Null';
        $BuildString = $BuildString.'ChID='.$Room.' ChUsed='.$Used.' ChUsedBy='.$UsedBy.'|';
    }
    my $OldLength = $rooms_ref->{'Length'}{'Length'} || 0;
    my $NewLength = length($BuildString);
    if ($OldLength > $NewLength) {
        $BuildString = sprintf("%-*s", $OldLength, $BuildString);
    }
    $rooms_ref->{'Length'}{'Length'} = $NewLength;
    sysseek($FFChans, 0, 0);
    syswrite $FFChans, $BuildString;
}

sub Rbm_CheckChildren {
    my ($checkID,$Parent,$channellist_ref,$rooms_ref) = @_;
    my (@children) = $$channellist_ref =~ /cid=(\d+) pid=$checkID channel/ig;
    return unless @children;
    my $child;
    foreach $child (@children) {
        $rooms_ref->{$Parent}{'RoomTree'} .= ','.$child
            unless $rooms_ref->{$Parent}{'RoomTree'} =~ /$child/ && $rooms_ref->{$Parent}{'RoomTree'};
        &Rbm_CheckChildren($child,$Parent,$channellist_ref,$rooms_ref);
    }
}

sub Rbm_CloneDetection {
    my ($online_ref,$CLID,$settings_ref,$disconnect) = @_;
    my $ClonePack_ref = &Rbm_CloneIcons2;
    my $OrgCLID;
    if (defined $disconnect) {
        my $CloneCnt = 0;
        my $CloneGroup;
        if ( exists $online_ref->{$CLID}{'Child'} ) {
#           We are a child clone
#           Find parent and update count, use existing servergroup.
            foreach $OrgCLID ( keys %$online_ref ) {
                if ( $online_ref->{$CLID}{'DBID'}
                        && $online_ref->{$OrgCLID}{'Clones'}
                        && $online_ref->{$CLID}{'DBID'} == $online_ref->{$OrgCLID}{'DBID'} ) {
                    --$online_ref->{$OrgCLID}{'Clones'};
                    $CloneCnt   = $online_ref->{$OrgCLID}{'Clones'};
                    $CloneGroup = $online_ref->{$OrgCLID}{'Group_Clone'};
                    if ($CloneCnt == 0) {
                        delete $online_ref->{$OrgCLID}{'Clones'};
                        delete $online_ref->{$OrgCLID}{'Group_Clone'};
                    }
                    last;
                }
            }
        }
        elsif ( exists $online_ref->{$CLID}{'Clones'} ) {
#           We are the Parent clone parting!
#           Find the first child clone and pass our data off.
            foreach $OrgCLID ( keys %$online_ref ) {
                next unless exists $online_ref->{$OrgCLID}{'DBID'};
                if ( $online_ref->{$CLID}{'DBID'} == $online_ref->{$OrgCLID}{'DBID'} && $CLID != $OrgCLID) {
                    $CloneCnt = $online_ref->{$CLID}{'Clones'} - 1;
                    $CloneGroup = $online_ref->{$CLID}{'Group_Clone'};
                    unless ($CloneCnt == 0) {
                        $online_ref->{$OrgCLID}{'Clones'} = $CloneCnt;
                        $online_ref->{$OrgCLID}{'Group_Clone'} = $CloneGroup;
                    }
                    else {
                        delete $online_ref->{$OrgCLID}{'Clones'};
                    }
                    $online_ref->{$OrgCLID}{'Parent'} = 1;
                    $online_ref->{$CLID}{'Child'} = 1;
                    delete $online_ref->{$CLID}{'Parent'};
                    delete $online_ref->{$OrgCLID}{'Child'};
                    if (exists $online_ref->{$CLID}{'Group_Rank'}) {
                        $online_ref->{$OrgCLID}{'Group_Rank'} = $online_ref->{$CLID}{'Group_Rank'};
                        $online_ref->{$OrgCLID}{'RankIcon'} = $online_ref->{$CLID}{'RankIcon'};
                        $online_ref->{$OrgCLID}{'Rank'} = $online_ref->{$CLID}{'Rank'};
                    }
                    if (exists $online_ref->{$CLID}{'Group_Trace'}) {
                        $online_ref->{$OrgCLID}{'Group_Trace'} = $online_ref->{$CLID}{'Group_Trace'};
                    }
                    if (exists $online_ref->{$CLID}{'Group_Ping'}) {
                        $online_ref->{$OrgCLID}{'Group_Ping'} = $online_ref->{$CLID}{'Group_Ping'};
                        $online_ref->{$OrgCLID}{'PingChecksum'} = $online_ref->{$CLID}{'PingChecksum'};
                    }
                    if (exists $online_ref->{$CLID}{'Group_Status'}) {
                        $online_ref->{$OrgCLID}{'Group_Status'} = $online_ref->{$CLID}{'Group_Status'};
                        $online_ref->{$OrgCLID}{'Status'} = $online_ref->{$CLID}{'Status'};
                        $online_ref->{$OrgCLID}{'StatusCountryName'} = $online_ref->{$CLID}{'StatusCountryName'};
                    }
                    last;
                }
            }
        }
        if ($CloneCnt == 0 && defined $CloneGroup && $settings_ref->{'Clone_Detection_On'} ne 0) {
#           Last clone to leave
            &$sub_send( 'servergroupdel sgid='.$CloneGroup.' force=1' );
        }
        return unless $CloneCnt > 0;
        if ( $settings_ref->{'Clone_Detection_On'} ne 0 ) {
            &$sub_send( 'servergroupaddperm sgid='.$CloneGroup
                .' permsid=i_icon_id permvalue='. $ClonePack_ref->[ $CloneCnt - 1 ] .' permskip=0 permnegated=0' );
        }
    }
    else {
        my ($cloneCLID,$detected);
        foreach $OrgCLID ( keys %$online_ref ) {
            if ( $online_ref->{$OrgCLID}{'DBID'}
                && $online_ref->{$CLID}{'DBID'} == $online_ref->{$OrgCLID}{'DBID'}
                && $CLID != $OrgCLID) {
                $detected = 1;
#               Clear other clone keys for processing later
                $online_ref->{$OrgCLID}{'Child'} = 1;
                delete $online_ref->{$OrgCLID}{'Clones'} if exists $online_ref->{$OrgCLID}{'Clones'};
                delete $online_ref->{$OrgCLID}{'Parent'};
                if (exists $online_ref->{$OrgCLID}{'Group_Clone'}) {
                    $online_ref->{$CLID}{'Group_Clone'} = $online_ref->{$OrgCLID}{'Group_Clone'};
                    delete $online_ref->{$OrgCLID}{'Group_Clone'};
                }
                if (exists $online_ref->{$OrgCLID}{'Group_Rank'}) {
                    $online_ref->{$CLID}{'Group_Rank'} = $online_ref->{$OrgCLID}{'Group_Rank'};
                    $online_ref->{$CLID}{'RankIcon'} = $online_ref->{$OrgCLID}{'RankIcon'};
                    $online_ref->{$CLID}{'Rank'} = $online_ref->{$OrgCLID}{'Rank'};
                    delete $online_ref->{$OrgCLID}{'Group_Rank'};
                }
                if (exists $online_ref->{$OrgCLID}{'Group_Trace'}) {
                    $online_ref->{$CLID}{'Group_Trace'} = $online_ref->{$OrgCLID}{'Group_Trace'};
                    delete $online_ref->{$OrgCLID}{'Group_Trace'};
                }
                if (exists $online_ref->{$OrgCLID}{'Group_Ping'}) {
                    $online_ref->{$CLID}{'Group_Ping'} = $online_ref->{$OrgCLID}{'Group_Ping'};
                    $online_ref->{$CLID}{'PingChecksum'} = $online_ref->{$OrgCLID}{'PingChecksum'};
                    delete $online_ref->{$OrgCLID}{'Group_Ping'};
                }
                if (exists $online_ref->{$OrgCLID}{'Group_Status'}) {
                    $online_ref->{$CLID}{'Group_Status'} = $online_ref->{$OrgCLID}{'Group_Status'};
                    $online_ref->{$CLID}{'Status'} = $online_ref->{$OrgCLID}{'Status'};
                    $online_ref->{$CLID}{'StatusCountryName'} = $online_ref->{$OrgCLID}{'StatusCountryName'};
                    delete $online_ref->{$OrgCLID}{'Group_Status'};
                }
            }
        }
        $online_ref->{$CLID}{'Parent'} = 1;
        return unless defined $detected;
        my $clonegrp;
        $online_ref->{$CLID}{'Clones'} = 0;
        foreach $cloneCLID ( keys %$online_ref ) {
            if ( exists $online_ref->{$cloneCLID}{'Child'}
                    && $online_ref->{$CLID}{'DBID'} == $online_ref->{$cloneCLID}{'DBID'} ) {
                ++$online_ref->{$CLID}{'Clones'};
            }
        }
        if ( !exists $online_ref->{$CLID}{'Group_Clone'} && $settings_ref->{'Clone_Detection_On'} ne 0 ) {
            my $GroupName = 'Clones\s'.$online_ref->{$CLID}{'Clones'}.'\s\s('.$CLID.')';
            &$sub_send( 'servergroupadd name='.substr($GroupName,0,29) );
            sleep 0.1;
            my $Search = $GroupName;
            $Search =~ s/\\s/\\\\s/gi;
            my $results_ref = &$sub_query('servergrouplist',
                    $Search.'.*?error id=0 msg=ok');
            return if !$results_ref;
            ($clonegrp) = $$results_ref =~ /sgid\=(\d+) name\=$Search /;
            return unless $clonegrp;
            if ( $settings_ref->{'Clone_Detection_Sort_Order'} !~ /Default/oi ) {
                &$sub_send( 'servergroupaddperm sgid='.$clonegrp
                    .' permsid=i_group_sort_id permvalue='.$settings_ref->{'Clone_Detection_Sort_Order'}.
                    ' permskip=0 permnegated=0|permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0' );
            }
            else {
                &$sub_send( 'servergroupaddperm sgid='.$clonegrp
                    .' permsid=i_group_sort_id permvalue=20 permskip=0 permnegated=0|permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0' );
            }
            $online_ref->{$CLID}{'Group_Clone'} = $clonegrp;

        }
        my $CloneCnt   = $online_ref->{$CLID}{'Clones'};
        my $CloneGroup = $online_ref->{$CLID}{'Group_Clone'};
        return if $CloneCnt < 1 || !defined $CloneGroup || $settings_ref->{'Clone_Detection_On'} eq 0;
        &$sub_log("INFO \t- Clone Detection\t- ".$online_ref->{$CLID}{'Nickname'}.' has '.$CloneCnt.' clones online');
        &$sub_send( 'servergroupaddperm sgid='.$CloneGroup
            .' permsid=i_icon_id permvalue='. $ClonePack_ref->[ $CloneCnt - 1 ] .' permskip=0 permnegated=0' );
        &$sub_send( 'servergroupaddclient sgid='.$CloneGroup.' cldbid='.$online_ref->{$CLID}{'DBID'} );
    }
}

sub Rbm_TxRxCalc {
    my ($sent,$recv) = @_;
    my ($txbytes,$rxbytes,$found_tx,$found_rx,$i) = (768,1640);
    for ($i = 0; $i < 15; $i++) {
        if ($sent < $txbytes && $sent >= ($txbytes - 768)) {
            $found_tx = $i;
        }
        elsif ($sent >= ($txbytes * 15)) {
            $found_tx = 15;
        }
        if ($recv < $rxbytes && $recv >= ($rxbytes - 1640)) {
            $found_rx = $i;
        }
        elsif ($recv >= ($rxbytes * 15)) {
            $found_rx = 15;
        }
        last if defined $found_tx && defined $found_rx;
        $txbytes = $txbytes + 768;
        $rxbytes = $rxbytes + 1640;
    }
    my $ByteMeter = &Rbm_BytesIcons();
    return $ByteMeter->{$found_tx}[$found_rx]
        if defined $found_tx && defined $found_rx;
}

sub Rbm_Traffic {
    my ($online_ref,$settings_ref,$groups_ref) = @_;
    return if $settings_ref->{'Traffic_Meter_On'} eq 0;
    my ($BlankIcon,$channel,$Tx,$TxCache,$Rx,$RxCache,$TxOffset,$RxOffset,
            $ChecksumCache,$icon_checksum,$client,$ChanID) = 242417915;
    foreach $client (keys %$online_ref) {
        $Tx = $online_ref->{$client}{'Tx'} || 0;
        $TxCache = $online_ref->{$client}{'TxCache'} || 0;
        $ChanID = $online_ref->{$client}{'Channel'} || undef;
        $TxOffset = $Tx - $TxCache;
        $ActiveChannels{$ChanID} = time if $TxOffset > 3596;
    }
    foreach $client (keys %$online_ref) {
        if ( exists $online_ref->{$client}{'PollTick'}
            && $online_ref->{$client}{'PollTick'} < $rbm_parent::PollTick) {
            next;
        }
        $ChecksumCache = $online_ref->{$client}{'Checksum'} || 0;
        $Tx = $online_ref->{$client}{'Tx'} || 0;
        $TxCache = $online_ref->{$client}{'TxCache'} || 0;
        $Rx = $online_ref->{$client}{'Rx'} || 0;
        $RxCache = $online_ref->{$client}{'RxCache'} || 0;
        $ChanID = $online_ref->{$client}{'Channel'} || 0;
        $TxOffset = $Tx - $TxCache;
        $RxOffset = $Rx - $RxCache;
        next if !$TxOffset && !$RxOffset;
        if (exists $ActiveChannels{$ChanID} && ($ActiveChannels{$ChanID} + 2) > time && ($TxOffset > 3596 || $RxOffset > 3596)) {
            $icon_checksum = &$sub_TxRx($TxOffset,$RxOffset);
            if ($ChecksumCache != $icon_checksum) {
                &$sub_send('clientaddperm cldbid='.$online_ref->{$client}{'DBID'}
                    .' permsid=i_icon_id permvalue='.$icon_checksum.' permskip=0 permnegated=0');
            }
        }
        elsif ($ChecksumCache != $BlankIcon) {
            &$sub_send('clientaddperm cldbid='.$online_ref->{$client}{'DBID'}
                .' permsid=i_icon_id permvalue='.$BlankIcon.' permskip=0 permnegated=0');
        }
        $online_ref->{$client}{'TxCache'} = $Tx;
        $online_ref->{$client}{'RxCache'} = $Rx;
        $online_ref->{$client}{'Checksum'} = $icon_checksum;
    }
}

sub Rbm_Ranking_Process {
    my ($client,$online_ref,$groups_ref,$settings_ref) = @_;
    return if $settings_ref->{'Military_Rank_On'} eq 0;
    return if !exists $online_ref->{$client}{'Parent'}
        || !exists $online_ref->{$client}{'SessionTime'};
    my ($cnt,$orgcnt,$scale_length,$SpecialLevel,$Icons_ref,$RankedNames2_ref,
            $GroupID,$ClientID,$BumpLevel,$CalcTime,$group_ref,$calculate,
            $rankup,$raw,$JoinedGroup,$i,$GroupName,$Search,$results_ref)
            = (0, 0, 62, 0);
    if ($settings_ref->{'Military_Rank_Icon_Pack'} == 1) {
        $scale_length     = 28;
        $Icons_ref        = &Rbm_RankedIcons3;
        $RankedNames2_ref = &Rbm_RankedIconsNames;
    }
    elsif ($settings_ref->{'Military_Rank_Icon_Pack'} == 2) {
        $scale_length     = 27;
        $Icons_ref        = &Rbm_RankedIcons2;
        $RankedNames2_ref = &Rbm_RankedIcons2Names;
    }
    else {
        $Icons_ref        = &Rbm_RankedIcons4;
    }
    $CalcTime = ( (sprintf "%.0f",($online_ref->{$client}{'SessionTime'} / 1000))
            + ($online_ref->{$client}{'CLTotalTime'} || 0) );
    $CalcTime = sprintf "%.0f", $CalcTime;
    $rankup = undef;
#   Check Privileged Client DBIDs
    my @Privileged = split /\,/, $settings_ref->{'Military_Rank_Privileged_Client_DBIDs'};
    foreach $raw ( @Privileged ) {
        ($ClientID,$BumpLevel) = split /-[>]?/, $raw;
        next unless $ClientID && $BumpLevel;
        if ( $online_ref->{$client}{'DBID'} == $ClientID ) {
#           Error control on levels larger than rank scale
            if ($BumpLevel >= $scale_length) {
                $SpecialLevel = $scale_length;
                next;
            }
            $SpecialLevel = $BumpLevel if $BumpLevel > $SpecialLevel;
        }
    }
#   Check Privileged Group IDs
    @Privileged    = split /\,/, $settings_ref->{'Military_Rank_Privileged_Group_IDs'};
    my @UserGroups = split /\,/, $online_ref->{$client}{'UserGroups'};
    foreach $raw ( @Privileged ) {
        ($GroupID,$BumpLevel) = split /-[>]?/, $raw;
        next unless $GroupID && $BumpLevel;
        foreach $JoinedGroup ( @UserGroups ) {
            if ( $JoinedGroup == $GroupID ) {
                if ($BumpLevel >= $scale_length) {
                    $SpecialLevel = $scale_length;
                    next;
                }
                $SpecialLevel = $BumpLevel if $BumpLevel > $SpecialLevel;
            }
        }
    }
#   Adjust for Privileged
    if ($SpecialLevel > 0) {
        for ( 0..$SpecialLevel ) {
            $cnt = $cnt + $settings_ref->{'Military_Rank_Requirements'} + sprintf "%.0f",($cnt / 4);
        }
        $CalcTime = $cnt + 1 + $CalcTime;
    }
    for ($i = $SpecialLevel; $i < $scale_length; $i++) {
        if ($CalcTime >= $cnt && $CalcTime < ($cnt + $settings_ref->{'Military_Rank_Requirements'} + sprintf "%.0f",($cnt / 4)) || $i == ($scale_length - 1)) {
            last if (defined $Icons_ref->[$i] && ($online_ref->{$client}{'RankIcon'} || 999999) == $Icons_ref->[$i]);
            unless ( exists $online_ref->{$client}{'Group_Rank'} ) {
                if ( !$Features{'Rank'.$i}{'Users'} ) {
                    if ( $settings_ref->{'Military_Rank_Icon_Pack'} =~ /default|1|2/oi ) {
                        my $name = $RankedNames2_ref->[$i];
                        $name =~ s/\\s/ /gi;
                        $GroupName = substr($name,0,23).'\s\s('.$i.')';
                        $GroupName =~ s/ /\\s/gi;
                    }
                    else {
                        $GroupName = 'Rank\s\s'.$i;
                    }
                    &$sub_send('servergroupadd name='.$GroupName);
                    sleep 0.2;
                    $Search = $GroupName;
                    $Search =~ s/\\s/\\\\s/gi;
                    $results_ref = &$sub_query('servergrouplist',
                            $Search.'.*?error id=0 msg=ok');
                    if (!$results_ref || $$results_ref !~ /$Search/) {
                        sleep 0.5;
                        $results_ref = &$sub_query('servergrouplist',
                            $Search.'.*?error id=0 msg=ok');
                    }
                    return if !$results_ref || $$results_ref !~ /$Search/;
                    ($GroupID) = $$results_ref =~ /sgid\=(\d+) name\=$Search /;
                    return unless $GroupID;

                    if ( $settings_ref->{'Military_Rank_Sort_Order'} !~ /Default/oi ) {
                        &$sub_send( 'servergroupaddperm sgid='.$GroupID
                            .' permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0|permsid=i_group_sort_id permvalue='
                            .$settings_ref->{'Military_Rank_Sort_Order'}.' permskip=0 permnegated=0|permsid=i_icon_id permvalue='
                            .$Icons_ref->[$i].' permskip=0 permnegated=0' );
                    }
                    else {
                        &$sub_send( 'servergroupaddperm sgid='.$GroupID
                            .' permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0|permsid=i_icon_id permvalue='
                            .$Icons_ref->[$i].' permskip=0 permnegated=0' );
                    }
                    $Features{'Rank'.$i}{'GroupID'} = $GroupID;
                    $Features{'Rank'.$i}{'Users'}   = 1;
                }
                else {
                    ++$Features{'Rank'.$i}{'Users'};
                    $GroupID = $Features{'Rank'.$i}{'GroupID'};
                }
                $online_ref->{$client}{'Group_Rank'} = $GroupID;
                $online_ref->{$client}{'Rank'}       = $i;
            }
            else {
                $rankup = $i + 1;
                if ( $settings_ref->{'Military_Rank_Icon_Pack'} =~ /default|1|2/oi ) {
                    $GroupName = substr($RankedNames2_ref->[$i],0,24) .'\s\s('.$client.')';
                }
                else {
                    $GroupName = 'Rank\s'.$i.'\s\s('.$client.')';
                }
                $calculate = &rbm_parent::Rbm_ReadSeconds( $settings_ref->{'Military_Rank_Requirements'} + (sprintf "%.0f",($cnt / 4)), 1, 1);
#               Cleanup old group / user from old group
                if ( $online_ref->{$client}{'Group_Rank'} ) {
                    &$sub_send( 'servergroupdelclient sgid='.$online_ref->{$client}{'Group_Rank'}
                            .' cldbid='.$online_ref->{$client}{'DBID'} );
                }
                my $ranked = $online_ref->{$client}{'Rank'};
                if (defined $ranked) {
                    --$Features{'Rank'.$ranked}{'Users'};
                    if ( $Features{'Rank'.$ranked}{'Users'} < 1 ) {
                        &$sub_send('servergroupdel sgid='.$Features{'Rank'.$ranked}{'GroupID'}.' force=1')
                                if $Features{'Rank'.$ranked}{'GroupID'};
                        delete $Features{'Rank'.$ranked};
                    }
                }
                if ( !$Features{'Rank'.$i}{'Users'} ) {
                    if ( $settings_ref->{'Military_Rank_Icon_Pack'} =~ /default|1|2/oi ) {
                        $GroupName = substr($RankedNames2_ref->[$i],0,24) .'\s\s('.$i.')';
                    }
                    else {
                        $GroupName = 'Rank\s\s'.$i;
                    }

                    &$sub_send('servergroupadd name='.substr($GroupName,0,29));
                    sleep 0.1;
                    $Search = $GroupName;
                    $Search =~ s/\\s/\\\\s/gi;
                    $results_ref = &$sub_query('servergrouplist',
                            $Search.'.*?error id=0 msg=ok');
                    return if !$results_ref;
                    ($GroupID) = $$results_ref =~ /sgid\=(\d+) name\=$Search /;
                    return unless $GroupID;

                    if ( $settings_ref->{'Military_Rank_Sort_Order'} !~ /Default/oi ) {
                        &$sub_send( 'servergroupaddperm sgid='.$GroupID
                            .' permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0|permsid=i_group_sort_id permvalue='
                            .$settings_ref->{'Military_Rank_Sort_Order'}.' permskip=0 permnegated=0|permsid=i_icon_id permvalue='
                            .$Icons_ref->[$i].' permskip=0 permnegated=0' );
                    }
                    else {
                        &$sub_send( 'servergroupaddperm sgid='.$GroupID
                            .' permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0|permsid=i_icon_id permvalue='
                            .$Icons_ref->[$i].' permskip=0 permnegated=0' );
                    }
                    $Features{'Rank'.$i}{'GroupID'} = $GroupID;
                    $Features{'Rank'.$i}{'Users'}   = 1;
                }
                else {
                    ++$Features{'Rank'.$i}{'Users'};
                    $GroupID = $Features{'Rank'.$i}{'GroupID'};
                }
            }
            &$sub_send( 'servergroupaddclient sgid='.$GroupID
                    .' cldbid='.$online_ref->{$client}{'DBID'} );
            unless ( $i <= ($online_ref->{$client}{'Rank'} || 0) ) {
                if ($settings_ref->{'Military_Rank_Icon_Pack'} eq 3) {
                    unless ($settings_ref->{'Military_Rank_Globally_Announce'} eq 0) {
                        &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[COLOR=MAROON][B]'
                            .$online_ref->{$client}{'Nickname'}
                            .'[/B]\sgained\srank\sto\slevel\s[B]'
                            .$i.'[/B][/COLOR]' );
                    }
                    unless ($settings_ref->{'Military_Rank_Privately_Announce'} eq 0) {
                        &$sub_send( 'sendtextmessage targetmode=1 target='.$client
                            .' msg=[COLOR=NAVY][B]'.$online_ref->{$client}{'Nickname'}
                            .'[/B]\syou\sgained\srank\sto\slevel\s[B]'.$i.'[/B][/COLOR]' );
                        &$sub_send( 'sendtextmessage targetmode=1 target='.$client
                            .' msg=[COLOR=MAROON]'.$$calculate
                            .'\srequired\sto\sachieve\sa\srank\sof\s'
                            .$rankup.'[/COLOR]' );
                    }
                }
                elsif ( defined $RankedNames2_ref->[$i] ) {
                    unless ($settings_ref->{'Military_Rank_Globally_Announce'} eq 0) {
                        &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[COLOR=NAVY][B]'
                            .$online_ref->{$client}{'Nickname'}
                            .'[/B]\sgained\srank\sto\s[B]'.$RankedNames2_ref->[$i]
                            .'[/B]\s(Level\s[B]'.$i.'[/B])[/COLOR]' );
                        &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[COLOR=MAROON]'
                            .$$calculate.'\srequired\sto\sachieve\sa\srank\sof\s'.$rankup.',\s'
                            .$RankedNames2_ref->[$rankup].'.[/COLOR]' )
                                if defined $RankedNames2_ref->[$rankup];
                    }
                    unless ($settings_ref->{'Military_Rank_Privately_Announce'} eq 0) {
                        &$sub_send( 'sendtextmessage targetmode=1 target='.$client
                            .' msg=[COLOR=NAVY][B]'.$online_ref->{$client}{'Nickname'}
                            .'[/B]\syou\sgained\srank\sto\s[B]'.$RankedNames2_ref->[$i]
                            .'[/B]\s(Rank\s[B]'.$i.'[/B])[/COLOR]');
                        &$sub_send( 'sendtextmessage targetmode=1 target='.$client
                            .' msg=[COLOR=MAROON]'.$$calculate
                            .'\srequired\sto\sachieve\sa\srank\sof\s'.$rankup
                            .',\s'.$RankedNames2_ref->[$rankup].'.[/COLOR]' )
                                if defined $RankedNames2_ref->[$rankup];
                    }
                }
            }
            $online_ref->{$client}{'RankIcon'}   = $Icons_ref->[$i];
            $online_ref->{$client}{'Rank'}       = $i;
            $online_ref->{$client}{'Group_Rank'} = $GroupID;
            &$sub_log("INFO \t- Ranking        \t- "
                    .$online_ref->{$client}{'Nickname'}.' went to level '.$i);
            last;
        }
        $cnt  = $cnt + $settings_ref->{'Military_Rank_Requirements'} + (sprintf "%.0f",($cnt / 4));
    }
    if ( exists $online_ref->{$client}{'Group_Rank'}
            && !$online_ref->{$client}{'Group_Rank_trig'}) {
        my $Special = '';
        $Special = ', bumping to level '. $SpecialLevel.'.' if $SpecialLevel > 0;
        &$sub_log("INFO \t- Ranking        \t- "
                .$online_ref->{$client}{'Nickname'}.' added to Military Rank GroupID: '
                .$online_ref->{$client}{'Group_Rank'}.$Special);
        $online_ref->{$client}{'Group_Rank_trig'} = 1;
    }
}

sub Rbm_Ranking {
    my ($online_ref,$groups_ref,$settings_ref) = @_;
    return if $settings_ref->{'Military_Rank_On'} eq 0;
    my $Client;
    if ( !exists $groups_ref->{'Rank_Interval'} ||
         $groups_ref->{'Rank_Interval'} < time - $settings_ref->{'Military_Rank_Interval'}) {
        foreach $Client ( keys %$online_ref ) {
            &Rbm_Ranking_Process($Client,$online_ref,$groups_ref,$settings_ref);
        }
        $groups_ref->{'Rank_Interval'} = time;
    }
}

sub Rbm_JoinFlood {
    my ($CLID,$online_ref,$settings_ref) = @_;
    my $FloodTime2 = $online_ref->{$CLID}{'JoinFlood2'} || undef;
    my $FloodTime3 = $online_ref->{$CLID}{'JoinFlood3'} || undef;
    my $FloodTime4 = $online_ref->{$CLID}{'JoinFlood4'} || undef;
    my $FloodTime5 = $online_ref->{$CLID}{'JoinFlood5'} || undef;
    my $FloodTime6 = $online_ref->{$CLID}{'JoinFlood6'} || undef;
    my $SET_FloodGaugeReq
            = $settings_ref->{'OnJoin_Reconnect_Gauge_Requirements'};
    if ( defined $FloodTime2 && $FloodTime2 > (time - $SET_FloodGaugeReq)
            && $FloodTime3 && $FloodTime3 > (time - $SET_FloodGaugeReq)
            && $FloodTime4 && $FloodTime4 > (time - $SET_FloodGaugeReq)
            && $FloodTime5 && $FloodTime5 > (time - $SET_FloodGaugeReq)
            && $FloodTime6 && $FloodTime6 > (time - $SET_FloodGaugeReq) ) {
        &$sub_send('sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]CONNECT\sGAUGE\s-[/COLOR][/B][COLOR=BLUE]\s6\sJoins\sdetected\sunder\s'.$SET_FloodGaugeReq.'\sseconds.[/COLOR]');
        &$sub_send('sendtextmessage targetmode=3 target=1 msg=[B][COLOR=BLUE]Banning\s'.$online_ref->{$CLID}{'Nickname'}.'![/COLOR][/B]');
        &$sub_send( 'banadd ip='.$online_ref->{$CLID}{'IP'}.' time=300 banreason=How\smany\stimes\sbefore\syou\slearn?' );
    }
    elsif ( defined $FloodTime2 && $FloodTime2 > (time - $SET_FloodGaugeReq)
            && $FloodTime3 && $FloodTime3 > (time - $SET_FloodGaugeReq)
            && $FloodTime4 && $FloodTime4 > (time - $SET_FloodGaugeReq)
            && $FloodTime5 && $FloodTime5 > (time - $SET_FloodGaugeReq) ) {
        &$sub_send('sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]CONNECT\sGAUGE\s-[/COLOR][/B][COLOR=BLUE]\s5\sJoins\sdetected\sunder\s'.$SET_FloodGaugeReq.'\sseconds.[/COLOR]');
        &$sub_send('sendtextmessage targetmode=3 target=1 msg=[B][COLOR=BLUE]Kicking\s'.$online_ref->{$CLID}{'Nickname'}.'![/COLOR][/B]');
        &$sub_send( 'clientkick clid='.$CLID.' reasonid=5 reasonmsg=You\swere\swarned.');
    }
    elsif ( defined $FloodTime2 && $FloodTime2 > (time - $SET_FloodGaugeReq)
            && $FloodTime3 && $FloodTime3 > (time - $SET_FloodGaugeReq)
            && $FloodTime4 && $FloodTime4 > (time - $SET_FloodGaugeReq) ) {
        &$sub_send('sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]CONNECT\sGAUGE\s-[/COLOR][/B][COLOR=BLUE]\s4\sJoins\sdetected\sunder\s'.$SET_FloodGaugeReq.'\sseconds.[/COLOR]');
        &$sub_send('sendtextmessage targetmode=3 target=1 msg=[B][COLOR=BLUE]If\syou\sreconnect\sagain\sI\'ll\shave\sto\spunish\syou.\sWe\sdon\'t\sput\sup\swith\sspam\shere.[/COLOR][/B]');
    }
    elsif ( defined $FloodTime2 && $FloodTime2 > (time - $SET_FloodGaugeReq)
            && $FloodTime3 && $FloodTime3 > (time - $SET_FloodGaugeReq)) {
        &$sub_send('sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]CONNECT\sGAUGE\s-[/COLOR][/B][COLOR=BLUE]\s3\sJoins\sdetected\sunder\s'.$SET_FloodGaugeReq.'\sseconds.[/COLOR]');
        &$sub_send('sendtextmessage targetmode=3 target=1 msg=[B][COLOR=BLUE]Welcome\sto\smy\sgrey\slist\s'.$online_ref->{$CLID}{'Nickname'}.'.[/COLOR][/B]');
    }
    elsif ( defined $FloodTime2 && $FloodTime2 > (time - $SET_FloodGaugeReq) ) {
        &$sub_send('sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]CONNECT\sGAUGE\s-[/COLOR][/B][COLOR=BLUE]\s2\sJoins\sdetected\sunder\s'.$SET_FloodGaugeReq.'\sseconds.[/COLOR]');
        &$sub_send('sendtextmessage targetmode=3 target=1 msg=[B][COLOR=BLUE]Mr.\sreconnect\sis\sback...[/COLOR][/B]');
    }
}

sub Rbm_Temperature_Update {
    my ($CLID,$Celsius,$online_ref,$settings_ref) = @_;
    return if exists $online_ref->{$CLID}{'Clones'}
            || !exists $online_ref->{$CLID}{'Parent'};
    my ($rounded,$groupID,$IconChecksum) = 0;
    my $Temps_ref     = &Rbm_Temps;
    if ($Celsius =~ /\.0$/o) {
        ($rounded) = $Celsius =~ /(\S+)\./o;
    }
    elsif ($Celsius ne 'Null' and $Celsius ne 0) {
        $rounded = int($Celsius + $Celsius/abs($Celsius * 2));
    }
    my $cloneCels2 = $online_ref->{$CLID}{'CelsiusRounded'};
    $rounded = '0' unless defined $rounded;
    return if $cloneCels2 and $rounded =~ /^$cloneCels2$/;
    $IconChecksum = $Temps_ref->{$rounded};
    return if !$IconChecksum or ($online_ref->{$CLID}{'Temps_IconChecksum'}
            and $online_ref->{$CLID}{'Temps_IconChecksum'} == $IconChecksum);
    my $cloneCels = $rounded;
    $cloneCels    =~ s/^\-//o;
    if ($cloneCels > 1 and defined $cloneCels2) {
        $cloneCels2 =~ s/^\-//o;
        return if $cloneCels == $cloneCels2;
    }
    $online_ref->{$CLID}{'Temps_IconChecksum'} = $IconChecksum;
    if ( $online_ref->{$CLID}{'Group_Temps'} ) {
        &$sub_send( 'servergroupdelclient sgid='.$online_ref->{$CLID}{'Group_Temps'}
                .' cldbid='.$online_ref->{$CLID}{'DBID'} );
    }
    if ( !$Features{'Temp'.$rounded}{'Users'} ) {
        my $GroupName;
        unless ($Celsius eq '-66') {
            my $Fahrenheit = ($rounded * 1.8) + 32;
            $Fahrenheit = int($Fahrenheit + $Fahrenheit/abs($Fahrenheit * 2)) if $Fahrenheit;
            $GroupName = $rounded.'°C\s'.$Fahrenheit.'°F';
            $GroupName = encode("utf8", $GroupName);
        }
        else {
            $GroupName = 'Temperature\sUnavailable';
        }
        &$sub_send('servergroupadd name='.substr($GroupName,0,29).' type=1');
        sleep 0.1;
        my $Search = $GroupName;
        $Search =~ s/\\s/\\\\s/go;
        my $results_ref = &$sub_query('servergrouplist', 'name='.$Search.'.*?error id=0 msg=ok');
        ($groupID) = $$results_ref   =~ /sgid\=(\d+) name\=$Search / if $results_ref;
        return unless $groupID;
        if ( $settings_ref->{'Temperatures_Sort_Order'} !~ /Default/oi ) {
            &$sub_send( 'servergroupaddperm sgid='.$groupID
                .' permsid=i_icon_id permvalue='.$IconChecksum
                .' permskip=0 permnegated=0|permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0|permsid=i_group_sort_id permvalue='
                .$settings_ref->{'Temperatures_Sort_Order'}.' permskip=0 permnegated=0' );
        }
        else {
            &$sub_send( 'servergroupaddperm sgid='.$groupID
                    .' permsid=i_icon_id permvalue='.$IconChecksum
                    .' permskip=0 permnegated=0|permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0' );
        }
        $Features{'Temp'.$rounded}{'GroupID'} = $groupID;
        $Features{'Temp'.$rounded}{'Users'}   = 1;
    }
    else {
        ++$Features{'Temp'.$rounded}{'Users'};
        $groupID = $Features{'Temp'.$rounded}{'GroupID'};
    }
    my $OldRounded = $online_ref->{$CLID}{'CelsiusRounded'};
    &$sub_send( 'servergroupaddclient sgid='.$groupID
        .' cldbid='.$online_ref->{$CLID}{'DBID'} );
#   Cleanup Old group
    if ($OldRounded && $Features{'Temp'.$OldRounded}{'GroupID'}) {
        --$Features{'Temp'.$OldRounded}{'Users'};
        if ( $Features{'Temp'.$OldRounded}{'Users'} < 1 ) {
            &$sub_send('servergroupdel sgid='.$Features{'Temp'.$OldRounded}{'GroupID'}.' force=1');
            delete $Features{'Temp'.$OldRounded};
        }
    }
    $online_ref->{$CLID}{'Group_Temps'} = $groupID;
    $online_ref->{$CLID}{'CelsiusRounded'} = $rounded;
    delete $online_ref->{$CLID}{'NOTempIcon'}
        if exists $online_ref->{$CLID}{'NOTempIcon'};
}

sub Rbm_ReadPings {
    my ($clid,$clping,$online_ref,$settings_ref,$FFClients_ref) = @_;
    return if $settings_ref->{'Ping_Meter_On'} eq 0
            or !$online_ref->{$clid}{'DBID'}
            or !$online_ref->{$clid}{'Parent'};
    my ($scale,$ping_scale,$ping_scale_limit,$GroupID,$i,$found_ping,$PingMeter)
            = (12,12,30,$online_ref->{$clid}{'Group_Ping'});
    $online_ref->{$clid}{'Ping'} = $clping if exists $online_ref->{$clid}{'Ping'};
#    my $SET_PingPack = $settings_ref->{'Ping_Meter_Icon_Pack'};
    $PingMeter = &Rbm_PingIcons();
#    $found_ping = 0 if $clping == 1;
    for ($i = 0; $i <= $ping_scale_limit; $i++) {
        if ($clping <= $ping_scale && $clping > ($ping_scale - $scale)) {
            $found_ping = $i;
            last;
        }
        elsif ($clping >= ($scale * $ping_scale_limit)) {
            $found_ping = $ping_scale_limit;
            last;
        }
        $ping_scale = $ping_scale + $scale;
    }
    $found_ping = 0 if $clping < 1;
    my $NewChecksum = $PingMeter->{$found_ping} if defined $found_ping;
    return unless $NewChecksum;
    unless ( $online_ref->{$clid}{'Group_Ping'} ) {
        my $GroupName = 'Ping\:\s'.$clping.'ms\s\s('.$clid.')';
        my $Dupe = $GroupName;
        $Dupe =~ s/\\s/\\\\s/gi;
        &$sub_send( 'servergroupadd name='.substr($GroupName,0,29) );
        sleep 0.1;
        my $results_ref = &$sub_query('servergrouplist', $Dupe.'.*?error id=0 msg=ok');
        return unless $results_ref;
        ($GroupID) = $$results_ref =~ /sgid\=(\d+) name\=$Dupe /;
        return unless $GroupID;
        if ( $settings_ref->{'Ping_Meter_Sort_Order'} !~ /default/oi ) {
            &$sub_send( 'servergroupaddperm sgid='.$GroupID
                    .' permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0|permsid=i_group_sort_id permvalue='
                    .$settings_ref->{'Ping_Meter_Sort_Order'}.' permskip=0 permnegated=0' );
        }
        else {
            &$sub_send( 'servergroupaddperm sgid='.$GroupID
                    .' permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0' );
        }
        &$sub_send( 'servergroupaddclient sgid='.$GroupID.' cldbid='
                .$online_ref->{$clid}{'DBID'} );
        $online_ref->{$clid}{'Group_Ping'} = $GroupID;
        &$sub_log("INFO \t- Ping Meter       \t- "
            .$online_ref->{$clid}{'Nickname'}.' added to Ping Meter GroupID: '
            .$GroupID);
    }
    if ( (($online_ref->{$clid}{'PingChecksum'} || 0) != $NewChecksum) && $GroupID ) {
        my $Newname = 'Ping\:\s'.$clping.'ms\s\s('.$clid.')';
        $online_ref->{$clid}{'PingChecksum'} = $NewChecksum;
        &$sub_send( 'servergroupaddperm sgid='.$GroupID
                .' permsid=i_icon_id permvalue='.$NewChecksum.' permskip=0 permnegated=0' );
        &$sub_send( 'servergrouprename sgid='.$GroupID
                .' name='.substr($Newname,0,29) );
    }
}

sub Rbm_TracePointer {
    my ($hops,$icon_pak) = @_;
    my ($Pak);
    if ($icon_pak =~ /Default|1/oi) {
        $Pak = &Rbm_HopsIcons2();
    }
    elsif ($icon_pak == 2) {
        $Pak = &Rbm_HopsIcons3();
    }
    elsif ($icon_pak == 3) {
        $Pak = &Rbm_HopsIcons4();
    }
    elsif ($icon_pak == 4) {
        $Pak = &Rbm_HopsIcons5();
    }
    return $Pak->[$hops];
}

sub Rbm_Traceroute {
    my ($CLID,$online_ref,$settings_ref,$groups_ref,$FFClients_ref) = @_;
    return if $settings_ref->{'TraceClients_On'} eq 0;
    return if exists $online_ref->{$CLID}{'Clones'};
    my $DBID = $online_ref->{ $CLID }{'DBID'};
    my $Hops = $FFClients_ref->{ $DBID }{'Hops'} || 0;
    my $HopsRead = $FFClients_ref->{ $DBID }{'HopsRead'};
    # Check memory for recent client trace
    if ( $Hops && $HopsRead && $HopsRead > (time - $settings_ref->{'TraceClients_Cache'}) ) {
        my $HopsPath = $FFClients_ref->{ $DBID }{'HopsPath'};
        &$sub_log("INFO \t- Traceroute      \t- Using DB entry for hops reading.");
        &Rbm_SetupTrace($online_ref,$settings_ref,$CLID,$Hops);
        &Rbm_DisplayTrace($online_ref,$settings_ref,$CLID,$Hops,$HopsPath) if $HopsPath;
    }
    elsif ( $CLID ) { # Fork thread for new client trace
        &$sub_log("INFO  \t- Traceroute      \t- Forked thread and tracing to ".$online_ref->{$CLID}{'Nickname'});
        if ($settings_ref->{'TraceClients_Message_Results_On'} ne 0) {
            &$sub_send( 'sendtextmessage targetmode=1 target='.$CLID
                .' msg=[COLOR=NAVY]\sPlease\swait\swhile\sI\strace\sthe\sroute\sbetween\syou\sand\sthe\sserver.[/COLOR]' );
        }
        my $SET_Method = $settings_ref->{'TraceClients_Trace_1_Type'};
        my $SET_Method2 = $settings_ref->{'TraceClients_Trace_2_Type'};
        my $SET_TraceDual = $settings_ref->{'TraceClients_Dual_Trace'};
        my $OSType = $settings_ref->{'OSType'};
        my $CLIP = $online_ref->{$CLID}{'IP'};
        if ($OSType =~ /Win/io) {
            system(1,$^X,"./rbm_tools/rbm_trace.pl", "$DBID", "$CLID", "$CLIP", "$OSType",
                "$SET_Method", "$SET_Method2", "$SET_TraceDual");
        }
        else {
            if (fork() == 0) {
                exec($^X,"./rbm_tools/rbm_trace.pl", "$DBID", "$CLID", "$CLIP", "$OSType",
                    "$SET_Method", "$SET_Method2", "$SET_TraceDual");
                exit 0;
            }
        }
    }
}

sub Rbm_SetupTrace {
    my ($online_ref,$settings_ref,$CLID,$HopsCnt) = @_;
    return unless exists $online_ref->{$CLID}{'DBID'};
    $HopsCnt = 1 if $HopsCnt < 1;
    $HopsCnt = 30 if $HopsCnt > 30;
    my $IconChecksum = &Rbm_TracePointer(($HopsCnt - 1),$settings_ref->{'TraceClients_Icon_Pack'});
    my $groupID;
    &$sub_log("INFO  \t- Traceroute      \t- Sending "
        .$online_ref->{$CLID}{'Nickname'}.'\'s Trace results.' );
    if ( !$Features{'TraceRoute'}{$HopsCnt} ) {
        my $word = 'Hops';
        $word = 'Hop' if $HopsCnt == 1;
        my $GroupName = $HopsCnt.'\s'.$word;
        &$sub_send('servergroupadd name='.substr($GroupName,0,29).' type=1');
        sleep 0.1;
        my $Search = $GroupName;
        $Search =~ s/\\s/\\\\s/gi;
        my $results_ref = &$sub_query('servergrouplist', $Search.'.*?error id=0 msg=ok');
        return unless $results_ref;
        ($groupID) = $$results_ref =~ /sgid\=(\d+) name\=$Search /;
        return unless $groupID;
        $Features{'TraceRoute'}{$HopsCnt} = 1;
        $Features{'TraceRoute'}{'GroupID'.$HopsCnt} = $groupID;
        if ( $settings_ref->{'TraceClients_Sort_Order'} !~ /Default/oi ) {
            &$sub_send( 'servergroupaddperm sgid='.$groupID
                .' permsid=i_icon_id permvalue='.$IconChecksum
                .' permskip=0 permnegated=0|permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0|permsid=i_group_sort_id permvalue='
                .$settings_ref->{'TraceClients_Sort_Order'}.' permskip=0 permnegated=0' );
        }
        else {
            &$sub_send( 'servergroupaddperm sgid='.$groupID
                .' permsid=i_icon_id permvalue='.$IconChecksum
                .' permskip=0 permnegated=0|permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0' );
        }
    }
    else {
        ++$Features{'TraceRoute'}{$HopsCnt};
        $groupID = $Features{'TraceRoute'}{'GroupID'.$HopsCnt};
    }
    &$sub_log("INFO \t- Traceroute      \t- "
        .$online_ref->{$CLID}{'Nickname'}.' added to Traceroute GroupID: '
        .$groupID);
    &$sub_send( 'servergroupaddclient sgid='.$groupID.' cldbid='
        .$online_ref->{$CLID}{'DBID'} );
    $online_ref->{$CLID}{'Group_Trace'} = $groupID;
}

sub Rbm_DisplayTrace {
    my ($online_ref,$settings_ref,$CLID,$HopsCnt,$Path) = @_;
    return if $settings_ref->{'TraceClients_Message_Results_On'} eq 0 or !$Path
            or !$rbm_parent::Booted or !exists $online_ref->{$CLID}{'DBID'};
    my $TracedDNS = $online_ref->{$CLID}{'DNS'};
    unless ($TracedDNS) {
        $TracedDNS = '';
    }
    else {
        $TracedDNS = '\s([B]'.$TracedDNS.'[/B])';
    }
    &$sub_send( 'sendtextmessage targetmode=1 target='.$CLID
            .' msg=[COLOR=BLUE]\n\nYour\strace\sresults\sfor\s'.$online_ref->{$CLID}{'IP'}.$TracedDNS.':[/COLOR]\n' );
    my ($line,@array);
    push @array, $1 while ($Path =~ /(.{1,940})/msxog);
    foreach $line (@array) {
        &$sub_send( 'sendtextmessage targetmode=1 target='.$CLID
                .' msg=[COLOR=BLUE]\n'.$line.'[/COLOR]' );
    }
    my @AdminGroupIDs = split /\,/, $settings_ref->{'TraceClients_Message_Results_Admin_GroupIDs'};
    my (@ClientGroupIDs,$Matched,$CLIDs,$GroupID,$currentgroup);
    foreach $GroupID (@AdminGroupIDs) {
        foreach $CLIDs (keys %$online_ref) {
            next if $CLIDs == $CLID || !exists $online_ref->{$CLIDs}{'UserGroups'};
            @ClientGroupIDs = split /\,/, $online_ref->{$CLIDs}{'UserGroups'};
            $Matched = undef;
            foreach $currentgroup (@ClientGroupIDs) {
                if ($currentgroup == $GroupID) {
                    $Matched = 1;
                    last;
                }
            }
            if (defined $Matched) {
                &$sub_send( 'sendtextmessage targetmode=1 target='.$CLIDs
                    .' msg=[COLOR=RED](INFO\s-\sAdministrators)\n\n[/COLOR][COLOR=BLUE]'.$online_ref->{$CLID}{'Nickname'}
                    .'\'s\strace\sresults\s'.$online_ref->{$CLID}{'IP'}.$TracedDNS.':[/COLOR]\n' );

                foreach $line (@array) {
                    &$sub_send( 'sendtextmessage targetmode=1 target='.$CLIDs
                            .' msg=[COLOR=BLUE]\n'.$line.'[/COLOR]' );
                }
            }
        }
    }
}

sub Rbm_SetupDNS {
    my ($CLID,$online_ref,$settings_ref,$FFClients_ref) = @_;
    my $DBID = $online_ref->{$CLID}{'DBID'} || return;
    return unless exists $online_ref->{$CLID}{'Nickname'};
    if ( $settings_ref->{'Reverse_DNS_Display_Privately'} ne 0 ) {
        &$sub_log("INFO  \t- Reverse DNS       \t- Sending "
            .$online_ref->{$CLID}{'Nickname'}.'\'s DNS results.');
        &$sub_send( 'sendtextmessage targetmode=1 target='.$CLID
            .' msg=[COLOR=NAVY][B]'.$online_ref->{$CLID}{'Nickname'}
            .'[/B]\syour\sreverse\sDNS\sis\s[B]'.$FFClients_ref->{$DBID}{'DNS'}
            .'[/B][/COLOR]' );
    }
}

sub Rbm_DNSLookup {
    my ($CLID,$online_ref,$settings_ref) = @_;
    return if $settings_ref->{'Reverse_DNS_On'} eq 0;
    if ($rbm_parent::OSType =~ /Win/io) {
        system(1,$^X,"./rbm_tools/rbm_dns.pl", $online_ref->{$CLID}{'IP'},
                $online_ref->{$CLID}{'DBID'},$CLID);
    }
    else {
        if (fork() == 0) {
            exec($^X,"./rbm_tools/rbm_dns.pl", $online_ref->{$CLID}{'IP'},
                    $online_ref->{$CLID}{'DBID'},$CLID);
            exit 0;
        }
    }
}

sub Rbm_RBLLookup {
    my ($online_ref,$settings_ref,$CLID,$FFClients_ref,$CLIP,$DBID) = @_;
    return if $settings_ref->{'RBL_Check_On'} eq 0;
    my @WhiteListed = split /\,/,$settings_ref->{'RBL_Check_WhiteList'};
    my $IP;
    if (exists $FFClients_ref->{$DBID}{'RBLRead'}
            && ($FFClients_ref->{$DBID}{'RBLRead'} > (time - $settings_ref->{'RBL_Check_Cache'}))) {
        &$sub_log("INFO \t- RBL Lookup      \t- " . $online_ref->{$CLID}{'Nickname'} . ' is Cached - Skipping.');
        return;
    }
    foreach $IP (@WhiteListed) {
        $IP =~ s/^\s|\s$//go;
        if ($CLIP eq $IP or ($CLIP =~ /^(127\.|192\.168|1\.1\.1|10\.)|^172\.(\d+)/o and (!$2 or $2 < 16 or $2 > 31))) {
            &$sub_log("INFO \t- RBL Lookup      \t- " . $online_ref->{$CLID}{'Nickname'} . ' ('.$IP.') is Whitelisted - Skipping.');
            return;
        }
    }
    &$sub_log("INFO \t- RBL Lookup      \t- Checking ".$CLIP.'...');
    if ($rbm_parent::OSType =~ /Win/io) {
        system(1,$^X,"./rbm_tools/rbm_rbl.pl", $online_ref->{$CLID}{'IP'},
                $online_ref->{$CLID}{'DBID'},$CLID,$settings_ref->{'RBL_Server'});
    }
    else {
        if (fork() == 0) {
            exec($^X,"./rbm_tools/rbm_rbl.pl", $online_ref->{$CLID}{'IP'},
                    $online_ref->{$CLID}{'DBID'},$CLID,$settings_ref->{'RBL_Server'});
            exit 0;
        }
    }
}

sub Rbm_ChannelWatch {
    my ($socket,$textmsg,$CLID,$NAME,$NowPlaying_ref,$settings_ref,$socketNum) = @_;
    my (@BotCount) = split /\,/,$settings_ref->{'Channel_Watch_Append_ChannelText_To_Tag_Client_DBIDs'};
    $socketNum = $socketNum - 2;
    my $Number = $BotCount[$socketNum];
    return unless $Number;
    my $orgtext = $textmsg;
    $textmsg =~ s/[(){}\[\]\!\@\#\$\%\^\&\*]//go;
    if (length($textmsg) > 28) {
        $textmsg = substr($textmsg,0,26);
        $textmsg =~ s/(\\)$//o;
        $textmsg =~ s/(\\s)$//o;
        $textmsg = '\s'.$textmsg.'\.\.\s';
    }
    else {
        $textmsg = substr($textmsg,0,28);
        $textmsg =~ s/(\\)$//o;
        $textmsg =~ s/(\\s)$//o;
        $textmsg = '\s'.$textmsg.'\s';
    }
    if ( $NowPlaying_ref->{'ChannelWatch'.$Number}{'GroupID'} ) {
        syswrite $socket, 'servergrouprename sgid='
                .$NowPlaying_ref->{'ChannelWatch'.$Number}{'GroupID'}.' name='.$textmsg.$nl;
        syswrite $socket, 'clientedit clid='.$CLID.' client_description='.substr($orgtext,0,79).$nl;
    }
    elsif ( !$NowPlaying_ref->{'ChannelWatch'.$Number}{'GroupID'} ) {
        my $Search = $textmsg;
        $Search =~ s/\\s/\\\\s/gi;
        syswrite $socket, 'servergroupadd name='.$textmsg.' type=1'.$nl;
        sleep 0.1;
        my $results_ref = &$sub_query('servergrouplist',$Search.'.*?error id=0 msg=ok',$socket);
        my ($group_id) = $$results_ref =~ /sgid=(\d+) name\=$Search /;
        return unless $group_id;
        $NowPlaying_ref->{'ChannelWatch'.$Number}{'GroupID'} = $group_id;
        syswrite $socket, 'servergroupaddperm sgid='.$group_id.' permsid=i_group_show_name_in_tree permvalue=2 permskip=0 permnegated=0'.$nl;
        syswrite $socket, 'servergroupaddclient sgid='.$group_id.' cldbid='.$Number.$nl;
        syswrite $socket, 'clientedit clid='.$CLID.' client_description='.substr($orgtext,0,79).$nl;
    }
}

sub Rbm_ChannelFloodJail {
    my ($CLID,$online_ref,$settings_ref,$groups_ref,$SET_PunishDuration,
        $FFClients_ref) = @_;
    my $DBID = $online_ref->{$CLID}{'DBID'};
#   Setup Default Channel
    if ( $settings_ref->{'Channel_Flood_Detection_Channel_ID'} =~ /default/oi ) {
        my $SET_ChanFloodDetectionChanName
            = $settings_ref->{'Channel_Flood_Detection_Channel_Name'};
        my $SET_ChanFloodDetectionChanOrder
            = $settings_ref->{'Channel_Flood_Detection_Channel_Sort_Order'};
        my ($cid_ref,$ChanName,$CLIDs);
        if ( $SET_ChanFloodDetectionChanName =~ /default/oi ) {
            $ChanName = 'Correctional\sFacility';
        }
        else {
            my $retrieve = &$sub_cleantext( $SET_ChanFloodDetectionChanName );
            $ChanName = $$retrieve;
        }
        my $CheckChanExists = &$sub_query('channelfind pattern='.$ChanName,'cid=\d+');
        my ($ChanID) = $$CheckChanExists =~ /cid=(\d+)/o if $CheckChanExists;
        if ( !$ChanID || !$CheckChanExists ) {
            &$sub_log("INFO \t- Channel Flood   \t- Couldn\'t find channel ".$ChanName, 1);
            &$sub_log("INFO \t- Channel Flood   \t- Creating channel ".$ChanName, 1);
            if ( $SET_ChanFloodDetectionChanOrder !~ /default/oi ) {
                &$sub_send('channelcreate channel_name='.substr($ChanName,0,29)
                    .' channel_topic=Channel\sFlood\sFacility channel_order='
                    .$SET_ChanFloodDetectionChanOrder.' channel_description=The\sRoom\sOf\sSHAME.');
            }
            else {
                &$sub_send('channelcreate channel_name='.substr($ChanName,0,29)
                    .' channel_topic=Channel\sFlood\sFacility channel_description=The\sRoom\sOf\sSHAME.');
            }
            $CheckChanExists = &$sub_query('channelfind pattern='.substr($ChanName,0,29),'cid=\d+');
            ($ChanID) = $$CheckChanExists =~ /cid=(\d+)/o if $CheckChanExists;
            return unless $ChanID;
        }
        &$sub_send( 'channeladdperm cid='.$ChanID
            .' permsid=i_client_needed_talk_power permvalue=100 permskip=0 permnegated=0|permsid=i_icon_id permvalue=356869037 permskip=0 permnegated=0' );
        &$sub_send( 'servergroupaddclient sgid='
            . $groups_ref->{'Group_Sticky'} .' cldbid='.$DBID );
#       Move client + DBID Clones
        &$sub_send( 'clientmove clid='.$CLID.' cid='.$ChanID );
        foreach $CLIDs (keys %$online_ref) {
            &$sub_send( 'clientmove clid='.$CLIDs.' cid='.$ChanID )
                    if $online_ref->{$CLIDs}{'DBID'} == $DBID;
        }
#       Move Bot back to default channel so the room gets distroyed when the last client parts.
        &$sub_send( 'clientmove clid='.$settings_ref->{'BotCLID'}
            .' cid='.$settings_ref->{'BotCHID'} );
#       Change time form seconds to readable format.
        $SET_PunishDuration = &rbm_parent::Rbm_ReadSeconds($SET_PunishDuration, 1, 1);
#       Inform virtual server globally
        if ( exists $online_ref->{$CLID}{'ChanFloodOld'} ) {
            &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]Channel\sFlood\s-\sDetected\sprevious\sinfraction\sfrom\s[/COLOR][COLOR=BLUE]'
                .$online_ref->{$CLID}{'Nickname'}.'[/COLOR][/B].' );
            &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]Channel\sFlood\s-\sIssuing\spunishment\sfor\sanother'
                .$$SET_PunishDuration.'.[/COLOR][/B]' );
            delete $online_ref->{$CLID}{'ChanFloodOld'};
        }
        else {
            &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]Channel\sFlood[/COLOR]\s-\s[COLOR=BLUE]'
                .$online_ref->{$CLID}{'Nickname'}.'\'s[/COLOR][COLOR=RED]\sstuck\sfor'
                .$$SET_PunishDuration.'.[/COLOR][/B]' );
        }
        if ( $settings_ref->{'Channel_Flood_Detection_Punish_Reason'} =~ /default/oi ) {
            &$sub_send( 'sendtextmessage targetmode=1 target='
                .$CLID.' msg=[COLOR=RED]You\sare\snow\sstuck\sfor'
                .$$SET_PunishDuration.'.[/COLOR]' );
            &$sub_send( 'sendtextmessage targetmode=1 target='
                .$CLID.' msg=[COLOR=RED]Please\sdo\snot\sflood\sthrough\sthe\schannels\snext\stime.[/COLOR]' );
        }
        else {
            my ($AdminMsg) = &$sub_cleantext( $settings_ref->{'Channel_Flood_Detection_Punish_Reason'} );
            &$sub_send( 'sendtextmessage targetmode=1 target='
                .$CLID.' msg=[COLOR=RED]'.$$AdminMsg.'[/COLOR]' );
        }
        &$sub_log("INFO   \t- Channel Flood   \t- Moved ". $online_ref->{$CLID}{'Nickname'} .' to channel '.$ChanName);
    }
#   Use Settings Channel ID
    else {
        &$sub_send( 'clientmove clid='.$CLID.' cid='
            .$settings_ref->{'Channel_Flood_Detection_Channel_ID'} );
        &$sub_log("INFO   \t- Channel Flood   \t- Detected "
            .$online_ref->{$CLID}{'Nickname'} .' flooding! Moving to channel ID '
            .$settings_ref->{'Channel_Flood_Detection_Channel_ID'}.'...');
    }
    $online_ref->{$CLID}{'ChanPunished'} = time;
    $FFClients_ref->{$DBID}{'ChanPunished'} = time;
}

sub Rbm_ChannelFlood {
    my ($online_ref,$settings_ref,$groups_ref,$FFClients_ref) = @_;
    return if $settings_ref->{'Channel_Flood_Detection_On'} eq 0;
#   Client behavior Queue
    my ($CLID,$infraction);
    foreach $CLID ( keys %$online_ref ) {
#       Clear away old infractions
        if ( exists $online_ref->{$CLID}{'ChanFloodQueue'}
                && !exists $online_ref->{$CLID}{'ChanPunishment'} ) {
            my (@Queued) = split /\,/, $online_ref->{$CLID}{'ChanFloodQueue'};
            my @NewQueue;
            foreach $infraction ( @Queued ) {
                if ( $infraction <= time - $settings_ref->{'Channel_Flood_Detection_Time_Limit'} ) {
                    next;
                }
                else {
                    push @NewQueue, $infraction;
                }
            }
            if ( scalar(@NewQueue) < 1 ) {
                delete $online_ref->{$CLID}{'ChanFloodQueue'};
            }
            else {
                $online_ref->{$CLID}{'ChanFloodQueue'} = join ',', @NewQueue;
            }
        }
#       Cleanup punished clients in channel
        if ( $online_ref->{$CLID}{'ChanPunished'}
            and $online_ref->{$CLID}{'ChanPunished'} < (time - $settings_ref->{'Channel_Flood_Detection_Punish_Duration'}) ) {
            if ( $settings_ref->{'Channel_Flood_Detection_CID_Move_Unstuck'} !~ /default/oi) {
                &$sub_send( 'clientmove clid='.$CLID.' cid='
                    .$settings_ref->{'Channel_Flood_Detection_CID_Move_Unstuck'} );
            }
            &$sub_send( 'sendtextmessage targetmode=1 target='
                .$CLID.' msg=[COLOR=NAVY]You\sare\snow\sfree\sto\smove\sabout.[/COLOR]' );
            &$sub_send( 'servergroupdelclient sgid='
                .$groups_ref->{'Group_Sticky'}.' cldbid='.$online_ref->{$CLID}{'DBID'} );
            delete $online_ref->{$CLID}{'ChanPunished'};
        }
#       Punish for reaching max tolerance level
        elsif ( exists $online_ref->{$CLID}{'ChanFloodNew'}
            && $online_ref->{$CLID}{'ChanFloodQueue'} ) {
#           See if this user's exempt first.
            my (@Queued) = split /\,/, $online_ref->{$CLID}{'ChanFloodQueue'};
            if ( scalar(@Queued) >= $settings_ref->{'Channel_Flood_Detection_Tolerance'} ) {

                my ($Exempt) = &rbm_parent::Rbm_CheckExemptions($CLID,
                    $settings_ref->{'Channel_Flood_Detection_Exempt_Group_IDs'});
                next if !defined $Exempt;

                &$sub_log("INFO \t- Channel Flood   \t- ".$online_ref->{$CLID}{'Nickname'}.' peaked our tolerance level of '.$settings_ref->{'Channel_Flood_Detection_Tolerance'});
                if ( $settings_ref->{'Channel_Flood_Detection_Punish_Reason'} =~ /default/oi ) {
                    $settings_ref->{'Channel_Flood_Detection_Punish_Reason'} = 'Removed\sfor\schannel\sflooding!\sRbMod';
                }
                else {
                    my $retrieve = &$sub_cleantext( $settings_ref->{'Channel_Flood_Detection_Punish_Reason'} );
                    $settings_ref->{'Channel_Flood_Detection_Punish_Reason'} = $$retrieve;
                }
                if ( $settings_ref->{'Channel_Flood_Detection_Ban'} ne 0 ) {
                    &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]Channel\sFlood\sDetected!\sBanning\s[/COLOR][COLOR=BLUE]'
                            .$online_ref->{$CLID}{'Nickname'}.'[/COLOR]![/B]' );
                    &$sub_send( 'banadd ip='.$online_ref->{$CLID}{'IP'}.' time='
                            .$settings_ref->{'Channel_Flood_Detection_Ban_Duration'}
                            .' banreason='.$settings_ref->{'Channel_Flood_Detection_Punish_Reason'} );
                    &$sub_log("INFO \t- Channel Flood  \t- Banning "
                            .$online_ref->{$CLID}{'Nickname'}.' for '
                            .$settings_ref->{'Channel_Flood_Detection_Ban_Duration'}.' seconds!');
                }
                elsif ( $settings_ref->{'Channel_Flood_Detection_Kick'} ne 0 ) {
                    &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]Channel\sFlood\sDetected!\sKicking\s[/COLOR][COLOR=BLUE]'
                            .$online_ref->{$CLID}{'Nickname'}.'![/COLOR]![/B]' );
                    &$sub_send( 'clientkick clid='.$CLID.' reasonid=5 reasonmsg='
                            .$settings_ref->{'Channel_Flood_Detection_Punish_Reason'} );
                    &$sub_log("INFO \t- Channel Flood   \t- Kicking "
                            .$online_ref->{$CLID}{'Nickname'}.'!');
                }
                else {
                    &Rbm_ChannelFloodJail($CLID,$online_ref,$settings_ref,
                            $groups_ref,$settings_ref->{'Channel_Flood_Detection_Punish_Duration'},
                            $FFClients_ref);
                }
                delete $online_ref->{$CLID}{'ChanFloodQueue'};
            }
            delete $online_ref->{$CLID}{'ChanFloodNew'};
        }
#       Punish for previous infractions, on reconnect.
        elsif ( exists $online_ref->{$CLID}{'ChanFloodOld'} ) {
            &$sub_log("INFO \t- Channel Flood   \t- "
                    .$online_ref->{$CLID}{'Nickname'}
                    .' has previous infractions from last login! Punishing user again.');
            &Rbm_ChannelFloodJail($CLID,$online_ref,$settings_ref,
                    $groups_ref,$settings_ref->{'Channel_Flood_Detection_Punish_Duration'},
                    $FFClients_ref);
            delete $online_ref->{$CLID}{'ChanFloodOld'};
        }
    }
}

sub Rbm_ChannelFloodQueue {
    my ($CLID,$ChanID,$online_ref,$settings_ref) = @_;
    return if $settings_ref->{'Channel_Flood_Detection_On'} eq 0;
#   Client behavior Queue
    unless ( exists $online_ref->{$CLID}{'ChanFloodQueue'} ) {
        $online_ref->{$CLID}{'ChanFloodQueue'} = time;
    }
    else {
        $online_ref->{$CLID}{'ChanFloodQueue'}
            = $online_ref->{$CLID}{'ChanFloodQueue'}.','.time;
    }
    $online_ref->{$CLID}{'ChanFloodNew'} = 1;
}

sub Rbm_ChannelPunish {
    my ($CLID,$ChanID,$online_ref,$settings_ref,$groups_ref) = @_;
    $online_ref->{$CLID}{'ChanPunishment'} = 1;
    &$sub_log("INFO \t- Channel Punishment \t- ".$online_ref->{$CLID}{'Nickname'}.' has been punished and placed in the sticky channel!');
    &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]Channel\sPunishment[/COLOR][/B][COLOR=NAVY]\s-\s[B]'.$online_ref->{$CLID}{'Nickname'}.'\'s[/B]\sbeen\spunished![/COLOR]' );
    &$sub_send( 'servergroupaddclient sgid='. $groups_ref->{'Group_Sticky'}
            .' cldbid='. $online_ref->{$CLID}{'DBID'} );
}

sub Rbm_ChannelDelPunish {
    my ($CLID,$ChanID,$online_ref,$settings_ref,$groups_ref) = @_;
    &$sub_send( 'servergroupdelclient sgid='. $groups_ref->{'Group_Sticky'}
            .' cldbid='. $online_ref->{$CLID}{'DBID'} );
    delete $online_ref->{$CLID}{'ChanPunishment'};
}

sub Rbm_NickLanguage {
    my ($CLID,$CLIP,$Check,$online_ref,$settings_ref,$FFClients_ref,
            $badwords_ref) = @_;
    return if $settings_ref->{'Nickname_Language_Filter_On'} eq 0;
#   See user's exempt first.
    if ( $settings_ref->{'Nickname_Language_Filter_Exempt_On'} ne 0 ) {
        my ($Exempt) = &rbm_parent::Rbm_CheckExemptions($CLID,
            $settings_ref->{'All_Language_Filters_Exempt_Group_IDs'});
        return if !defined $Exempt;
    }
    return if $Check =~ /TeamSpeakUser[\d]?/oi;
    my ($found,$badword);
    $Check =~ s/\\s/ /go;
#    my $retrieve = &$sub_cleantext( $Check );
    &$sub_log("INFO  \t- Nickname Language\t- Checking ".$Check.' against word list...');
    foreach $badword (@$badwords_ref) {
        if ($Check =~ /\Q$badword\E/i) {
            $found = $badword;
            $found =~ s/ /\\s/go;
        }
        else {
            next;
        }
        my $SET_SwearNicknamesBan = $settings_ref->{'Nickname_Language_Filter_Ban'};
        my $SET_SwearNicknamesBanTime = $settings_ref->{'Nickname_Language_Filter_Ban_Time'};
        my $SET_SwearNicknamesReason = $settings_ref->{'Nickname_Language_Filter_Punish_Reason'};
        if ( $SET_SwearNicknamesReason =~ /default/oi ) {
            $SET_SwearNicknamesReason = 'You\scan\'t\suse\s'.$found.'\shere!\s-\sRbMod';
        }
        else {
            my $new = &$sub_cleantext( $SET_SwearNicknamesReason );
            $SET_SwearNicknamesReason = $$new;
        }
        if ($SET_SwearNicknamesBan ne 0) {
            &$sub_log( "INFO  \t- Nickname Language\t- Banning "
                    .$Check.' for badword '.$found.'!' );
            &$sub_send( 'banadd ip='.$CLIP
                    .' time='.$SET_SwearNicknamesBanTime.' banreason='
                    .$SET_SwearNicknamesReason );
        }
        else {
            &$sub_log( "INFO  \t- Nickname Language\t- Kicking "
                    .$Check.' for badword '.$found.'!' );
            &$sub_send( 'clientkick clid='.$CLID
                    .' reasonid=5 reasonmsg='.$SET_SwearNicknamesReason);
        }
        return 1;
    }
}

sub Rbm_ChanLanguage {
    my ($online_ref,$channellist_ref,$badwords_ref,$settings_ref,
        $allrooms_ref,$randomwords_ref) = @_;
    return $badwords_ref if $settings_ref->{'Channel_Name_Language_Filter_On'} eq 0;
    if ( ($settings_ref->{'Channel_Name_Language_Filter_Timestamp'} || 0) > (time - $settings_ref->{'Channel_Name_Language_Filter_Interval'}) ){
        return $badwords_ref;
    }
    $settings_ref->{'Channel_Name_Language_Filter_Timestamp'} = time;
    unless ( $channellist_ref ) {
       $channellist_ref = &$sub_query('channellist',
            'cid=\d+.*?channel_name=\S+.*?error id=0 msg=ok');
        unless ( $channellist_ref ) {
            return $badwords_ref;
        }
    }
    my @Split = split /\|/,$$channellist_ref;
    my ($cnt,$limit,$Tmp,$Trig,$ChanID,$ChanName,$random,$NewLine,$Meaning,
            $split,$badword) = 0;
#   Check for rbm_badwords Updates.
    my $File = 'rbm_extras/rbm_badwords.cf';
    my $DateTime = stat($File)->mtime;
    if ( $DateTime ne ($settings_ref->{'BadwordsDate'} || 0) ) {
        $settings_ref->{'BadwordsDate'} = $DateTime;
        ($badwords_ref) = &rbm_parent::Rbm_LoadConfigs($File);
    }
    foreach $split ( @Split ) {
        ($Tmp,$Trig,$ChanID,$ChanName) = undef;
        ($ChanID, $ChanName) = $split =~ /cid=(\d+).*?channel_name=(\S+)/o;
        next if !$ChanName or $ChanName =~ /spacer/o;
        $Tmp = $ChanName;
        if ( $allrooms_ref->{$ChanID}{'Name2'}
            && $allrooms_ref->{$ChanID}{'Name2'} eq $ChanName) {
            next;
        }
        if ( !$allrooms_ref->{$ChanID}{'Name2'} ) {
            $allrooms_ref->{$ChanID}{'Name2'} = 'Null';
        }
        if ( $allrooms_ref->{$ChanID}{'Name2'} &&
            $ChanName ne $allrooms_ref->{$ChanID}{'Name2'} ) {
            unless ( $allrooms_ref->{$ChanID}{'Name2'} eq 'Null' ) {
                &$sub_log("INFO  \t- Global Language\t- Checking ".$ChanName.' for bad word(s)...');
            }
#           Scan for bad words now.
            ($random,$NewLine,$Meaning) = undef;
            foreach $badword (@$badwords_ref) {
                $random = &Rbm_RandomHashKey($randomwords_ref);
                $NewLine = $randomwords_ref->{$random};
                $Meaning = &$sub_cleantext($NewLine);
                $random = &$sub_cleantext($random);
                $$random = ucfirst($$random);
                $ChanName =~ s/\\s/ /go;
                if ( ($ChanName =~ /\Q$badword\E/i or $badword =~ /\Q$ChanName\E/i)
                        and length($ChanName) > 2 ) {
                    $Tmp =~ s/$badword/$$random/gi;
                    $allrooms_ref->{$ChanID}{'Name2'} = $Tmp;
                    $Trig = 1;
                }
                else {
                    $ChanName =~ s/ /\\s/go;
                    $allrooms_ref->{$ChanID}{'Name2'} = $ChanName;
                }
            }
        }
        if ( $Trig ) {
            &$sub_log("INFO  \t- Global Language\t- Renaming ".$ChanName.' for bad word(s)!');
            my ($time,$ap,$day,$date) = &$sub_proctime();
            my $string = $$time.'\s'.$$ap;
            my $timestamp = &$sub_logformat( $string, 1 );
            my $Line = $Tmp;
            $Line =~ s`(.+)\\s[\S]+`$1`gi if length($Line) > 45;
            if ( length($Tmp) < 2 ) {
                $Line = 'Filtered\s'.$$timestamp;
            }
            $Line = substr($Line,0,44);
            $allrooms_ref->{$ChanID}{'Name2'} = $Line;
            my $response_ref = &$sub_send('channeledit cid='.$ChanID.' channel_name='.$Line);
            return $badwords_ref;
        }

        if ($cnt >= 15) {
            &$sub_log("INFO  \t- Global Language\t- Checked over ".$cnt.' channels, continuing.');
            last;
        }
        ++$cnt;
    }
    return $badwords_ref;
}

sub Rbm_GroupProtect {
    my ($CLID,$online_ref,$settings_ref) = @_;
    return if $settings_ref->{'Group_Protected_On'} eq 0;
    my $DBID = $online_ref->{$CLID}{'DBID'};
    my ($checked,$Group,$Clients,@ProtectIDs,$GroupID,$raw,$groupID,$SafeDBID,
            $KickReason,$Safe);
    my @ProtectList = $settings_ref->{'Group_Protected_GroupID_MemberIDs'} =~ /([\d]*\-[\>]?\[.+?\])\,?/go;
    my @CLGroups = split /\,/, $online_ref->{$CLID}{'UserGroups'};

    if ( $settings_ref->{'Group_Protected_Kick_Reason'} =~ /default/oi ) {
        $KickReason = 'Unauthorized\sGroup\sDetected';
    }
    else {
        my $result;
        $result = &$sub_cleantext( $settings_ref->{'Group_Protected_Kick_Reason'} );
        $KickReason = $$result;
    }
    &$sub_log("INFO  \t- Group Protect    \t- Checking "
            .$online_ref->{$CLID}{'Nickname'}.'\'s group permissions.' );

    my ($GuardClient,$skip);

    foreach $raw ( @ProtectList ) {
        ($Group,$Clients) = $raw =~ /([\d]*)\-[\>]?\[(.+?)\]/go;
        @ProtectIDs = split /\,/, $Clients;
        $GuardClient = undef;
        foreach $groupID (@CLGroups) {
            ($checked,$Safe) = undef;
            if ( $groupID == $Group ) {
                $checked = 1;
                foreach $SafeDBID ( @ProtectIDs ) {
                    if ( $SafeDBID == $DBID ) {
                        $Safe = $groupID;
                        $GuardClient = $groupID;
                        last;
                    }
                }
            }
            if ( $checked && !defined $Safe ) {
                &$sub_log("WARN  \t- Group Protect    \t- ".$online_ref->{$CLID}{'Nickname'}.'\'s not allowed in GroupID: '.$Group.'!' );
                &$sub_send( 'servergroupdelclient sgid='.$Group.' cldbid='.$DBID );
                &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]Group\sProtection\s-\s[/COLOR][COLOR=MAROON]Detected\sUnauthorized\sAccess\sFrom\s[/COLOR][COLOR=BLUE]'
                    .$online_ref->{$CLID}{'Nickname'}.'[/COLOR][COLOR=MAROON]![/COLOR][/B].' );
                &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]Group\sProtection\s-\s[/COLOR][COLOR=MAROON]Removing\s[/COLOR][COLOR=BLUE]'
                    .$online_ref->{$CLID}{'Nickname'}.'[/COLOR][COLOR=MAROON]\sFrom\sGroupID:\s[/COLOR][COLOR=BLUE]'.$Group.'[/COLOR][/B].' );
                if ( $settings_ref->{'Group_Protected_Kick'} ne 0 ) {
                    &$sub_send( 'clientkick clid='.$CLID
                        .' reasonid=5 reasonmsg='.$KickReason );
                }
                if ( $settings_ref->{'Group_Protected_Ban'} ne 0 ) {
                    &$sub_send( 'clientkick clid='.$CLID
                        .' reasonid=5 reasonmsg='.$KickReason );
                    if ( $settings_ref->{'Group_Protected_Ban_Reason'} =~ /default/oi ) {
                        $settings_ref->{'Group_Protected_Ban_Reason'} = 'Never\stouch\smy\sfriends!';
                    }
                    else {
                        my $retrieve = &$sub_cleantext( $settings_ref->{'Group_Protected_Ban_Reason'} );
                        $settings_ref->{'Group_Protected_Ban_Reason'} = $$retrieve;
                    }
                    &$sub_send( 'banadd ip='.$online_ref->{$CLID}{'IP'}.' time='
                        .$settings_ref->{'Group_Protected_Ban_Duration'}.' banreason='.$settings_ref->{'Group_Protected_Ban_Reason'} );
                    &$sub_send( 'clientkick clid='.$CLID
                        .' reasonid=5 reasonmsg='.$settings_ref->{'Group_Protected_Ban_Reason'} );
                }
                return;
            }
        }
        if (!$checked && !$GuardClient) {
            $skip = 1;
            foreach $SafeDBID ( @ProtectIDs ) {
                if ( $SafeDBID == $DBID ) {
                    $skip = undef;
                    last;
                }
            }
            if (!defined $skip) {
                &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]Group\sProtection\s-\s[/COLOR][COLOR=MAROON]Detected\sUnauthorized\sRemoval\sOf\s[/COLOR][COLOR=BLUE]'
                    .$online_ref->{$CLID}{'Nickname'}.'[/COLOR][COLOR=MAROON]![/COLOR][/B].' );
                &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]Group\sProtection\s-\s[/COLOR][COLOR=MAROON]Adding\s[/COLOR][COLOR=BLUE]'
                    .$online_ref->{$CLID}{'Nickname'}.'[/COLOR][COLOR=MAROON]\sTo\sGroupID:\s[/COLOR][COLOR=BLUE]'.$Group.'[/COLOR][/B].' );
                &$sub_send( 'servergroupaddclient sgid='.$Group.' cldbid='.$DBID );
                return;
            }
        }
    }
}

sub Rbm_NickProtectCheckExempt {
    my ($CLID,$online_ref,$settings_ref,$SET_ProtectedGroups) = @_;
#       check to see if this user can skip rules.
    my ($Exempt,$GroupID);
    if ( $settings_ref->{'Nickname_Protected_Punish_All'} eq 0 ) {
        my @CurrentGroups = split /\,/,$online_ref->{$CLID}{'UserGroups'};
        foreach $GroupID (@CurrentGroups) {
            ($Exempt) = $SET_ProtectedGroups =~ /($GroupID)/;
            return 1 if defined $Exempt;
        }
    }
    return undef;
}

sub Rbm_NickProtect {
    my ($online_ref,$settings_ref,$FFClients_ref) = @_;
    return if $settings_ref->{'Nickname_Protected_On'} eq 0;
    if ( ($settings_ref->{'Nickname_Protected_TimeStamp'} || 0)
        > (time - $settings_ref->{'Nickname_Protected_Interval'}) ){
        return;
    }
    $settings_ref->{'Nickname_Protected_TimeStamp'} = time;
    my ($CLID,$LIVECLID,$JoinedGroup,$FFDBID);
    foreach $CLID ( keys %$online_ref ) {
        if ( exists $online_ref->{$CLID}{'Nickname'}
                && $online_ref->{$CLID}{'Nickname'}
                ne ($online_ref->{$CLID}{'PrevNickname2'} || '') ) {
            my $Check = $online_ref->{$CLID}{'Nickname'};
            my $DBID  = $online_ref->{$CLID}{'DBID'};
            my ($FoundProtected,$Exempt);
            $online_ref->{$CLID}{'PrevNickname2'} = $Check;
            next if $Check =~ /TeamSpeakUser/oi;
#           Check Online First
            foreach $LIVECLID ( keys %$online_ref ) {
                next if $LIVECLID == $CLID
                    || !exists $online_ref->{$LIVECLID}{'UserGroups'};
                my $Nick = $online_ref->{$LIVECLID}{'Nickname'};

                if ( $Check =~ /\Q$Nick\E/i ) {
                    ($Exempt) = &Rbm_NickProtectCheckExempt($CLID,$online_ref,
                        $settings_ref,$settings_ref->{'Nickname_Protected_Group_IDs'});

                    if ( $Exempt ) {
                        &$sub_log("INFO \t- Nick Protect  \t- "
                            .$online_ref->{$LIVECLID}{'Nickname'}
                            .'\'s safe from protected name rules.');
                        return;
                    }

                    &$sub_log("INFO \t- Nick Protect  \t- Checking "
                        .$online_ref->{$CLID}{'Nickname'}.' against protected user list.');

                    my (@CurrentGroups) = split(/\,/, $online_ref->{$LIVECLID}{'UserGroups'} );
                    foreach $JoinedGroup (@CurrentGroups) {
                        ($FoundProtected) = $settings_ref->{'Nickname_Protected_Group_IDs'} =~ /($JoinedGroup)/;
                        if ( $FoundProtected ) {
                            &$sub_log("INFO \t- Nick Protect  \t- Detected the name "
                                .$Check.' matches protected online user '.$online_ref->{$LIVECLID}{'Nickname'}.'!');
                            &Rbm_Punish($CLID,$online_ref->{$LIVECLID}{'Nickname'},
                                $online_ref,$settings_ref,'NickProtect');
                            last;
                        }
                    }
                    last;
                }
            }
#           Check Offline IF not found online
            unless ( $FoundProtected ) {
                foreach $FFDBID ( keys %$FFClients_ref ) {
                    next if !exists $FFClients_ref->{ $FFDBID }{'DBID'} || $DBID == $FFClients_ref->{ $FFDBID }{'DBID'};
                    my $Nick = $FFClients_ref->{$FFDBID}{'Nickname'};
                    if ( exists $FFClients_ref->{$FFDBID}{'UserGroups'}
                            && (exists $FFClients_ref->{$FFDBID}{'Nickname'}
                            && $FFClients_ref->{$FFDBID}{'Nickname'} =~ /\Q$Check\E/i
                            || $Check =~ /\Q$Nick\E/i) ) {

                        ($Exempt) = &Rbm_NickProtectCheckExempt($CLID,$online_ref,
                                $settings_ref,$settings_ref->{'Nickname_Protected_Group_IDs'});

                        if ( $Exempt ) {
                            &$sub_log("INFO \t- Nick Protect  \t- "
                                .$Check.' matches one of our exemptions, moving on.');
                            last;
                        }

                        my (@CurrentGroups) = split(/\,/, $FFClients_ref->{$FFDBID}{'UserGroups'} );
                        foreach $JoinedGroup (@CurrentGroups) {
                            ($FoundProtected) = $settings_ref->{'Nickname_Protected_Group_IDs'} =~ /($JoinedGroup)/i;
                            if ( $FoundProtected ) {
                                &$sub_log("INFO \t- Nick Protect  \t- Detected the name "
                                    .$Check.' matches protected offline user '.$FFClients_ref->{$FFDBID}{'Nickname'}.'!');
                                &Rbm_Punish($CLID,$FFClients_ref->{$FFDBID}{'Nickname'},
                                    $online_ref,$settings_ref,'NickProtect');
                            }
                        }
                    }
                }
            }
        }
    }
}

sub Rbm_Punish {
    my ($CLID,$Misc,$online_ref,$settings_ref,$type) = @_;
    if ( $type eq 'NickProtect' ) {
        my $SET_ProtectedPunishReason = $settings_ref->{'Nickname_Protected_Punish_Reason'};
        if ( $SET_ProtectedPunishReason =~ /default/oi ) {
            $SET_ProtectedPunishReason = 'You\scan\'t\suse\s'.$Misc.'\shere!\s-\sRbMod';
        }
        else {
            my $retrieve = &$sub_cleantext( $SET_ProtectedPunishReason );
            $SET_ProtectedPunishReason = $$retrieve;
        }
        if ($settings_ref->{'Nickname_Protected_Ban'} ne 0) {
            &$sub_log( "INFO \t- Nick Protect  \t- Detected "
                .$Misc.'! Banning '.$online_ref->{$CLID}{'Nickname'}.'!' );
            &$sub_send( 'banadd ip='.$online_ref->{$CLID}{'IP'}
                .' time='.$settings_ref->{'Nickname_Protected_Ban_Time'}.' banreason='
                .$SET_ProtectedPunishReason );
        }
        else {
            &$sub_log( "INFO \t- Nick Protect  \t- Detected "
                .$Misc.'! Kicking '.$online_ref->{$CLID}{'Nickname'}.'!' );
            &$sub_send( 'clientkick clid='.$CLID
                .' reasonid=5 reasonmsg='.$SET_ProtectedPunishReason );
        }
    }
}

sub Rbm_AutoMoveNotice {
    my ($ChanMoveID,$CLID,$online_ref,$settings_ref,$FFClients_ref,$rooms_ref)
            = @_;
    return unless exists $rooms_ref->{$ChanMoveID}{'Name'};
    my $msg;
    my $SET_AutoMoveClientNotice = $settings_ref->{'Automove_Client_OnJoin_Notice_On'};
    if ( $SET_AutoMoveClientNotice =~ /default/oi ) {
        $msg = 'You\shave\sbeen\splaced\sin\syour\srespective\schannel\s[B]'
            .$rooms_ref->{$ChanMoveID}{'Name'}.'[/B]\s([B]'.$ChanMoveID.'[/B]).';
    }
    else {
        my $retieve = &$sub_cleantext( $SET_AutoMoveClientNotice );
        $msg = $$retieve;
    }
    &$sub_send( 'sendtextmessage targetmode=1 target='.$CLID
        .' msg=[COLOR=NAVY]'.$msg.'[/COLOR]' );
}

sub Rbm_AutoMove {
    my ($CLID,$online_ref,$settings_ref,$FFClients_ref,$channellist_ref,
            $rooms_ref,$CCode,$Phase1,$GEOACTIVE) = @_;
#    say 'Entering auto-mover';
    return if exists $online_ref->{$CLID}{'ChanPunished'};
    return unless $channellist_ref && exists $online_ref->{$CLID}{'Nickname'};
    return if exists $online_ref->{$CLID}{'Automoved'};
    if (!$CCode) {
       if ($online_ref->{$CLID}{'CCode'}) {
           $CCode = $online_ref->{$CLID}{'CCode'};
       }
       elsif ($online_ref->{$CLID}{'CCode2'}) {
           $CCode = $online_ref->{$CLID}{'CCode2'};
       }
    }
    my @MoveIDs = split /\,/, $settings_ref->{'Automove_Client_OnJoin_DBIDs'};
    my $DBID = $online_ref->{$CLID}{'DBID'};
    my ($CLMoveID,$ChanID,$GroupMoveID,$ChanMoveID,$rawsplit,$CLGroup,$RoomName,
            $LiveRoom,$MoveMe,$match,$ParentID,$NAME,$CheckChanExists,$NextID,
            $Created);

    if ( $DBID and $FFClients_ref->{$DBID}{'UserGroups'}
            or $online_ref->{$CLID}{'UserGroups'} ) {
        foreach $rawsplit (@MoveIDs) {
            ($CLMoveID,$ChanID) = undef;
            ($CLMoveID,$ChanID) = split /[-][\>]?/, $rawsplit;
            next unless $ChanID;
            return if ($online_ref->{$CLID}{'Channel'} || -1) == $ChanID;
            if ( $DBID == $CLMoveID and ($online_ref->{$CLID}{'Channel'} || -1) != $ChanID ) {
                &$sub_log( "INFO  \t- Auto-Move      \t- Placing individual client "
                        .$online_ref->{$CLID}{'Nickname'}.' (CLID: '.$CLID
                        .') in channel ID: '.$ChanID.'...' );
                &$sub_send( 'clientmove clid='.$CLID.' cid='.$ChanID );
                &Rbm_AutoMoveNotice($ChanID,$CLID,$online_ref,$settings_ref,
                        $FFClients_ref,$rooms_ref) if $settings_ref->{'Automove_Client_OnJoin_Notice_On'} ne 0;
                $online_ref->{$CLID}{'Automoved'} = 1;
                return;
            }
        }
        my $groups = ($FFClients_ref->{$DBID}{'UserGroups'} || 0).','.($online_ref->{$CLID}{'UserGroups'} || 0);
        my @CLMoveGroupIDs = split /\,/, $settings_ref->{'Automove_Client_OnJoin_Group_IDs'};
        my @CLGroups = split /\,/, $groups;
        foreach $CLGroup (@CLGroups) {
            $rawsplit = undef;
            foreach $rawsplit (@CLMoveGroupIDs) {
                ($GroupMoveID,$ChanMoveID) = undef;
                ($GroupMoveID,$ChanMoveID) = split /[-][>]?/, $rawsplit;
                next unless $ChanMoveID;
                return if ($online_ref->{$CLID}{'Channel'} || -1) == $ChanMoveID;
                if ( $GroupMoveID == $CLGroup
                        && ($online_ref->{$CLID}{'Channel'} || -1) != ($ChanID || 0) ) {
                    &$sub_log( "INFO  \t- Auto-Move      \t- Placing group ID: "
                            .$GroupMoveID.' ('.$online_ref->{$CLID}{'Nickname'}
                            .' CLID: '.$CLID.') in channel ID: '.$ChanMoveID.'...' );
                    &$sub_send('clientmove clid='.$CLID.' cid='.$ChanMoveID);
                    &Rbm_AutoMoveNotice($ChanMoveID,$CLID,$online_ref,$settings_ref,
                        $FFClients_ref,$rooms_ref) if $settings_ref->{'Automove_Client_OnJoin_Notice_On'} ne 0;
                    $online_ref->{$CLID}{'Automoved'} = 1;
                    return;
                }
            }
        }
    }
#   City / Region / CCode move
    my @LiveRooms = $$channellist_ref =~ /cid=(\d+)/go;
    my $region = $online_ref->{$CLID}{'Region'};
    if ( defined $CCode && $settings_ref->{'Automove_Client_OnJoin_Existing_CCode_On'} ne 0 ) { # CCode2
        foreach $LiveRoom (@LiveRooms) {
            ($RoomName) = $$channellist_ref =~ /cid\=$LiveRoom pid=\d+ channel_order=\d+ channel_name=(\S+) /;
            if ( $RoomName && $RoomName =~ /(^$CCode\\s|\\s$CCode$)/ ) {
                $RoomName =~ s/\\s/ /go;
                $MoveMe = $LiveRoom;
                &$sub_log( "INFO  \t- Auto-Move      \t- Placing "
                        .$online_ref->{$CLID}{'Nickname'}.' in 2 Digit CCode Channel '.$RoomName );
                last;
            }
        }
    }
    if ($MoveMe && !$GEOACTIVE) {
        &$sub_send( 'clientmove clid='.$CLID.' cid='.$MoveMe );
    }
    return if $Phase1;
    return if $settings_ref->{'Automove_Client_OnJoin_Geo_Channel_On'} eq 1 and $Phase1;
    #   Setup channels if we made it this far
    my (@matches,$newRegion);
    if ($CCode) {
#       CCode2
        my $CCodes_ref = &Rbm_CCodes;
        my $GroupName = $CCodes_ref->{$CCode}{Name};
        my $CleanedName = &$sub_cleantext($GroupName);
#        return unless $CleanedName;
        $NAME = encode("utf8", $NAME);
        $NAME = substr($$CleanedName,0,29);
        $NAME =~ s/ /\\s/go;
        $CheckChanExists = &$sub_query('channelfind pattern='.$NAME,
                'cid=\d+ channel_name.*?error id=0 msg=ok');
        if ($CheckChanExists) {
            my @matches = split /\|/,$$CheckChanExists;
            my $newNAME = $NAME;
            $newNAME =~ s/\\s/\\\\s/go;
            foreach $match (@matches) {
                if ($match =~ /cid=(\d+) channel_name\=([\S]+$newNAME|$newNAME[\S]+|$newNAME)/s) {
                    $NextID = $1;
                    &$sub_send('channeladdperm cid='.$NextID.
                        ' permsid=i_channel_max_depth permvalue=-1 permskip=0 permnegated=0|permsid=i_icon_id permvalue='
                        .$CCodes_ref->{$CCode}{Icon}.' permskip=0 permnegated=0');
                }
            }
        }

        $CheckChanExists = undef;
        unless ($NextID) {
            if (exists $settings_ref->{'Automove_Client_OnJoin_Geo_Channel_Sort_Order'}
                    && $settings_ref->{'Automove_Client_OnJoin_Geo_Channel_Sort_Order'} =~ /\d+/o ) {
                $CheckChanExists = &$sub_query('channelcreate channel_name='
                        .$NAME.' channel_flag_permanent=1 channel_order='
                        .$settings_ref->{'Automove_Client_OnJoin_Geo_Channel_Sort_Order'},
                        'cid=\d+');
                if (!$CheckChanExists) {
                    $CheckChanExists = &$sub_query('channelcreate channel_name='
                        .$NAME.' channel_flag_permanent=1', 'cid=\d+\n');
                }
            }
            else {
                $CheckChanExists = &$sub_query('channelcreate channel_name='
                        .$NAME.' channel_flag_permanent=1', 'cid=\d+\n');
            }
            if ($CheckChanExists) {
                ($ParentID) = $$CheckChanExists =~ /cid=(\d+)/o;
                $Created = $ParentID;
                &$sub_send('channeladdperm cid='.$ParentID.
                        ' permsid=i_channel_max_depth permvalue=-1 permskip=0 permnegated=0|permsid=i_icon_id permvalue='
                        .$CCodes_ref->{$CCode}{Icon}.' permskip=0 permnegated=0');
            }
        }
        else {
            $ParentID = $NextID if $NextID;
        }
    }
    if ( $online_ref->{$CLID}{'Region'} && $online_ref->{$CLID}{'Region'} =~ /\S{2,}/o ) {
#       Region
        my $ChanName = $online_ref->{$CLID}{'Region'};
        $ChanName = encode("utf8", $ChanName);
        $ChanName = substr($ChanName,0,29);
#       $ChanName = &rbm_parent::process_ascii_chars($ChanName);
        $ChanName =~ s/ /\\s/go;
        $CheckChanExists = &$sub_query('channelfind pattern='.$ChanName,
                'cid=\d+ channel_name.*?error id=0 msg=ok');
        $NextID = undef;
        if ($CheckChanExists) {
            @matches = split /\|/,$$CheckChanExists;
            $newRegion = $ChanName;
            $newRegion =~ s/\\s/\\\\s/go;
            foreach $match (@matches) {
                if ($match =~ /cid\=(\d+) channel\_name\=([\S]+?$newRegion|$newRegion\\s[\S]*?|[\S]+?\\s[\W]$newRegion[\W]|$newRegion)/s) {
                    $NextID = $1;
                    last;
                }
            }
        }
        if ($ParentID && !$NextID) {
            $CheckChanExists = &$sub_query('channelcreate channel_name='
                    .$ChanName.' channel_flag_permanent=1 cpid='.$ParentID,
                    'cid=\d+\n');
            ($ParentID) = $$CheckChanExists =~ /cid=(\d+)\n/o if $CheckChanExists;
            if ($ParentID) {
                &$sub_send('channeladdperm cid='.$ParentID
                .' permsid=i_channel_max_depth permvalue=-1 permskip=0 permnegated=0');
                $Created = $ParentID;
            }
        }
        elsif (!$NextID) {
            $CheckChanExists = &$sub_query('channelcreate channel_name='.$ChanName
                    .' channel_flag_permanent=1', 'cid=\d+\n');
            ($ParentID) = $$CheckChanExists =~ /cid=(\d+)\n/o if $CheckChanExists;
            &$sub_send('channeladdperm cid='.$ParentID
            .' permsid=i_channel_max_depth permvalue=-1 permskip=0 permnegated=0');
            $Created = $ParentID;
        }
        $ParentID = $NextID if $NextID;
    }
    if ( $online_ref->{$CLID}{'City'} && $online_ref->{$CLID}{'City'} =~ /\S{2,}/o ) {
#       City
        my $city = $online_ref->{$CLID}{'City'};
        $city = encode("utf8", $city);
        $city = substr($city,0,29);
        $city =~ s/ /\\s/go;
        $CheckChanExists = &$sub_query('channelfind pattern='.$city,
                'cid=\d+ channel_name.*?error id=0 msg=ok');
        $NextID = undef;
        if ($CheckChanExists) {
            @matches = split /\|/,$$CheckChanExists;
            my $newCity = $city;
            $newCity =~ s/\\s/\\\\s/go;
            foreach $match (@matches) {
                if ( $match =~ /cid=(\d+) channel_name\=$newCity/s ) {
                    $NextID = $1;
                    last;
                }
            }
        }
        $CheckChanExists = undef;
        if ($ParentID && !$NextID) {
            $CheckChanExists = &$sub_query('channelcreate channel_name='.$city
                .' channel_flag_permanent=1 cpid='.$ParentID, 'cid=\d+\n');
            $Created = $ParentID;
        }
        elsif (!$NextID) {
            $CheckChanExists = &$sub_query('channelcreate channel_name='
                .$city.' channel_flag_permanent=1', 'cid=\d+\n');
        }
        my ($ID) = $$CheckChanExists =~ /cid=(\d+)\n/o if defined $CheckChanExists;
        if ($ID && !$NextID) {
            $ParentID = $ID;
            $Created = $ParentID;
        }
        elsif ($NextID) {
            $ParentID = $NextID;
        }
    }
    &$sub_log( "INFO  \t- Auto-Move      \t- Placing "
        .$online_ref->{$CLID}{'Nickname'}.' in Geographical Channel.' );
    &$sub_send( 'clientmove clid='.$CLID.' cid='.$ParentID ) if $ParentID;
    &$sub_send( 'clientmove clid='.$CLID.' cid='.$MoveMe ) if !$ParentID && $MoveMe;
    &$sub_send( 'setclientchannelgroup cgid='.$rbm_parent::ChanAdminID.' cid='.$Created.' cldbid='.$DBID ) if $Created;
}

sub Rbm_ClientStatus {
    my ($CLID,$ChanID,$Idletime,$online_ref,$settings_ref,$groups_ref,$bootup,
        $idle,$afk,$live) = @_;
    return if exists $online_ref->{$CLID}{'Clones'}
            || !exists $online_ref->{$CLID}{'Parent'};
    my $groupID = $online_ref->{$CLID}{'Group_Status'}
            if exists $online_ref->{$CLID}{'Group_Status'};
    my $LiveIcon = 285283699;
    my $IdleIcon = 293012181;
    my $AFKIcon = 205067414;
#   Setup 'Live' icon for on-joins.
    if ( $bootup ) {
        my $SET_StatusSort = $settings_ref->{'Status_Sort_Order'};
#       Display Country Information Tag
        my $GroupName = 'Status\s'.$CLID;
        my $CCode = $online_ref->{$CLID}{'CCode'} || $online_ref->{$CLID}{'CCode2'};
        if ( $CCode ) {
            my $CCodeNames_ref = &$sub_countries;
            $GroupName = $CCodeNames_ref->{$CCode}{Name};
            $GroupName =~ s/ /\\s/g;
        }
        if ( $CCode or $online_ref->{$CLID}{'City'}
                or $online_ref->{$CLID}{'Region'} ) {
            if ( $online_ref->{$CLID}{'City'} && $online_ref->{$CLID}{'City'} ne 'Null' ) {
                my $line  = $online_ref->{$CLID}{'City'};
                $line .= ',\s'.$online_ref->{$CLID}{'Region'} if $online_ref->{$CLID}{'Region'};
                $line .= ',\s'.$CCode if defined $CCode;
                $GroupName = substr($line,0,23).'\s-\s'.$CLID;
            }
            elsif( $online_ref->{$CLID}{'Region'} && $online_ref->{$CLID}{'Region'} ne 'Null' ) {
                my $line .= ',\s'.$online_ref->{$CLID}{'Region'};
                $line .= ',\s'.$CCode if defined $CCode;
                $GroupName = substr($line,0,23).'\s-\s'.$CLID;
            }
            else {
                $GroupName =~ s/ /\\s/go;
                $GroupName = substr($GroupName,0,21).'\s-\s'.$CLID;
            }
            $GroupName =~ s/ /\\s/go;
            $GroupName = substr($GroupName,0,29);
            $GroupName = encode("utf8", $GroupName);
            $online_ref->{$CLID}{'StatusCountryName'} = $GroupName;
        }
        if ($online_ref->{$CLID}{'Group_Status'} && $bootup == 2) {
            &$sub_send('servergrouprename sgid='.$online_ref->{$CLID}{'Group_Status'}
                    .' name='.substr($GroupName,0,29));
            return;
        }
        else {
            return unless $online_ref->{$CLID}{'Nickname'};
            &$sub_send('servergroupadd name='.substr($GroupName,0,29).' type=1');
            sleep 0.1;
            my $search = $GroupName;
            $search =~ s/\\s/\\\\s/go;
            my $results_ref = &$sub_query('servergrouplist',$search);
            unless ($results_ref) {
               sleep 0.2;
               $results_ref = &$sub_query('servergrouplist',
                    $search.'.*?error id=0 msg=ok');
            }
            return unless $results_ref;
            ($groupID) = $$results_ref =~ /sgid\=(\d+) name\=$search /;
            return unless $groupID;

            &$sub_log( "INFO  \t- Status Group      \t- "
                    .$online_ref->{$CLID}{'Nickname'}. ' added to Status GroupID: '
                    .$groupID );
            if ( $SET_StatusSort !~ /Default/oi ) {
                &$sub_send( 'servergroupaddperm sgid='.$groupID
                    .' permsid=i_icon_id permvalue='.$LiveIcon
                    .' permskip=0 permnegated=0|permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0|permsid=i_group_sort_id permvalue='.$SET_StatusSort.' permskip=0 permnegated=0' );
            }
            else {
                &$sub_send( 'servergroupaddperm sgid='.$groupID
                    .' permsid=i_icon_id permvalue='.$LiveIcon
                    .' permskip=0 permnegated=0|permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0' );
            }
            &$sub_send( 'servergroupaddclient sgid='.$groupID.' cldbid='
                .$online_ref->{$CLID}{'DBID'} );
            $online_ref->{$CLID}{'Group_Status'} = $groupID;
            $online_ref->{$CLID}{'Status'} = 'Live';

            if ( $settings_ref->{'Status_Display_Country_OnJoin'} ne 0
                    && $groupID && ($CCode || $online_ref->{$CLID}{'City'}
                    || $online_ref->{$CLID}{'Region'}) ) {
                &$sub_send( 'servergroupaddperm sgid='.$groupID
                    .' permsid=i_group_show_name_in_tree permvalue=2 permskip=0 permnegated=0' );
            }
            return;
        }
    }
    return unless $groupID;
    my $SET_IdleChanID = $settings_ref->{'Automove_Client_AFK_Channel_ID'};
    my $SET_IdleOn = $settings_ref->{'Automove_Client_AFK_On'};
    if ( $idle ) {
        &$sub_send( 'servergroupaddperm sgid='.$groupID
            .' permsid=i_icon_id permvalue='.$IdleIcon.' permskip=0 permnegated=0' );
    }
    elsif ( $SET_IdleOn ne 0 && ($ChanID == $SET_IdleChanID) || $afk ) {
        &$sub_send( 'servergroupaddperm sgid='.$groupID
            .' permsid=i_icon_id permvalue='.$AFKIcon.' permskip=0 permnegated=0' );
        $online_ref->{$CLID}{'Status'} = 'AFK';
    }
    elsif ( $live ) {
        &$sub_send('servergroupaddperm sgid='.$groupID.' permsid=i_icon_id permvalue='
                .$LiveIcon.' permskip=0 permnegated=0' );
        $online_ref->{$CLID}{'Status'} = 'Live';
        delete $online_ref->{$CLID}{'AFKRoomID'}
                if exists $online_ref->{$CLID}{'AFKRoomID'};
        delete $online_ref->{$CLID}{'BeforeAFKRoomID'}
                if exists $online_ref->{$CLID}{'BeforeAFKRoomID'};
    }
}

sub Rbm_Recording {
    my ($CLID,$online_ref,$settings_ref) = @_;
    my @CurrentGroups = split(/\,/, $online_ref->{$CLID}{'UserGroups'} );
    my @ExemptGroups = split(/\,/, $settings_ref->{'Recording_Detect_Exempt_Group_IDs'} );
    my ($GroupID,$Exempt);
    foreach $GroupID (@CurrentGroups) {
        foreach $Exempt (@ExemptGroups) {
            if ( $Exempt == $GroupID ) {
                $online_ref->{$CLID}{'RecordExempt'} = 1;
                &$sub_log( "INFO  \t- Record Detection    \t- ".
                    $online_ref->{$CLID}{'Nickname'}.'\'s exempt from Recording Detection...');
                return;
            }
        }
    }
    &$sub_log( "INFO  \t- Record Detection    \t- ".
                    $online_ref->{$CLID}{'Nickname'}.' is not allowed to record! Kicking client.');
    &$sub_send( 'clientkick clid='.$CLID.' reasonid=5 reasonmsg=Detected\sunauthorized\srecording!' );
}

sub Rbm_TagLine {
    my ($CLID,$online_ref,$settings_ref) = @_;
    my $TagLine = $online_ref->{$CLID}{'TagLine'} || $online_ref->{$CLID}{'description'};
    return unless $TagLine;
    &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[B][COLOR=\#CD4F39]'
            .$online_ref->{$CLID}{'Nickname'}.':[/COLOR]\s[COLOR=\#3579DC]'.$TagLine.'[/B][/COLOR]' );
}

sub Rbm_IdleMover {
    my ($CLID,$ChanID,$online_ref,$settings_ref,$groups_ref) = @_;
    my $SET_IdleMoveChanID = $settings_ref->{'Automove_Client_AFK_Channel_ID'};
    my $SET_IdleAFKLimit   = $settings_ref->{'Automove_Client_AFK_Time_Requirement'};
    my @CurrentGroups      = split /\,/, $online_ref->{$CLID}{'UserGroups'};
    my @ExemptGroups       = split /\,/, $settings_ref->{'Automove_Client_AFK_Exempt_Group_IDs'};
    my @ExemptChannels     = split /\,/, $settings_ref->{'Automove_Client_AFK_Exempt_Channel_IDs'};
    my ($GroupID,$ChannelID,$Exempt);

#   Check exempt channels
    foreach $ChannelID (@ExemptChannels) {
        if ( $ChannelID == $online_ref->{$CLID}{'Channel'} ) {
            return;
        }
    }
#   Check exempt groups
    foreach $GroupID (@CurrentGroups) {
        foreach $Exempt (@ExemptGroups) {
            if ( $Exempt == $GroupID ) {
                $online_ref->{$CLID}{'ExemptFromIdleMove'} = 1;
                &$sub_log( "INFO  \t- Idle-Move      \t- ".
                        $online_ref->{$CLID}{'Nickname'}.'\'s exempt from AFK-Move...');
                return;
            }
        }
    }
    $online_ref->{$CLID}{'AFKRoomID'}       = $SET_IdleMoveChanID;
    $online_ref->{$CLID}{'BeforeAFKRoomID'} = $ChanID;
    my ($Elapsed) = &rbm_parent::Rbm_ReadSeconds( $SET_IdleAFKLimit, 1 );
    $$Elapsed =~ s/^\\s//go;
    &$sub_send(
            'sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]AFK\sMove\s-\s[/COLOR][COLOR=BLUE]'.
            $online_ref->{$CLID}{'Nickname'}.'[/COLOR][COLOR=RED]\swas\sactive\s[/COLOR][COLOR=MAROON]'.
            $$Elapsed.'.[/COLOR][COLOR=RED]\sMoving\sClient.[/COLOR][/B]' );

    &$sub_send( 'clientmove clid='.$CLID.' cid='.$SET_IdleMoveChanID);
    &$sub_log("INFO  \t- Idle-Move      \t- Moved "
            .$online_ref->{$CLID}{'Nickname'}.' for laying inactive over '.$$Elapsed.' seconds.' );
}

sub Rbm_Trig_Help {
    my ($clid,$client_nickname,$BotName_ref2,$settings_ref,$gameicons_ref,
            $msg) = @_;
    if ($msg =~ /!help\\suse/oi) {
#       Check for rbm_triggers.cf Updates.
        my $File = 'rbm_extras/rbm_triggers.cf';
        my $DateTime = ctime(stat($File)->mtime);
        if ( $DateTime ne ($settings_ref->{'TriggersDate'} || 0) ) {
            $settings_ref->{'TriggersDate'} = $DateTime;
            ($gameicons_ref) = &rbm_parent::Rbm_LoadConfigs($File);
        }
        my $size = keys %$gameicons_ref;
        my $tags = join '\,\s',sort keys %$gameicons_ref;
        $tags =~ s/ /\\s/go;
        &$sub_send( 'sendtextmessage targetmode=1 target='.$clid.' msg=\t[B]!Use\sHelp\sMenu.[/B]'.$nl );
        &$sub_send( 'sendtextmessage targetmode=1 target='.$clid.' msg=\t[COLOR=BLUE]Below\sare\s[B]'.$size.'[/B]\savailable\stags\sto\schoose\sbetween.[/COLOR]'.$nl );
        my ($tagchunk,@array);
        push @array, $1 while ($tags =~ /(.{1,1000})/msxog);
        foreach $tagchunk (@array) {
            &$sub_send( 'sendtextmessage targetmode=1 target='.$clid.' msg=\t[COLOR=NAVY]'.substr($tagchunk,0,1005).'[/COLOR]'.$nl );
        }
        &$sub_send( 'sendtextmessage targetmode=1 target='.$clid.' msg=\t[COLOR=BLUE][U]Example[/U]:[/COLOR]\s!use\scoffee'.$nl );
    }
    else {
        my $space = '\t' x 8;
        my @Help = ( '\t[B]Help\sMenu.[/B]\n\n',
            $space.'[COLOR=BLUE]Issue\sany\sof\sthe\sfollowing\s[U]!Triggers[/U],\n',
            $space.'either\sprivately,\sor\sglobally\sif\spermitted.[/COLOR]\n\n',
            $space.'[COLOR=RED][B]!Help\s[/B][/COLOR]-\sThis\sHelp\sMenu.\n',
            $space.'[COLOR=RED][B]!Quote\s[/B][/COLOR]-\sRandom\sQuote.\n',
            $space.'[COLOR=RED][B]!Word\s[/B][/COLOR]-\sRandom\sWord.\n',
            $space.'[COLOR=RED][B]!Seen\s[/B]<Nickname\p#Channel>[/COLOR]\s-\sDisplay\sclients\slast\schannel\sand\stime\sseen\sresults.\n',
            $space.'[COLOR=RED][B]!Seenlast\s[/B]<1-25>[/COLOR]\s-\sDisplay\sa\srange\sof\srecent\sclients\sonline.\n',
            $space.'[COLOR=RED][B]!Use\s[/B]<Tag\sName>[/COLOR]\s-\sAdd\sa\scustom\sIcon/Tag\sbeside\syour\sname.\n',
            $space.'[COLOR=RED][B]!Unuse\s[/B][/COLOR]-\sDrop\sfrom\scurrent\sIcon/Tag\sgroup.\n',
            $space.'[COLOR=RED][B]!Help\sUse\s[/B][/COLOR]\s-\sDisplay\savailable\scustom\sIcon/Tag\snames.\n',
            $space.'[COLOR=RED][B]!Tagline\s[/B]<Custom\sMessage>[/COLOR]\s-\sAdd\syour\sown\spersonal\sgreeting.\n',
            $space.'[COLOR=RED][B]!Deltag\s[/B][/COLOR]\s-\sDelete\syour\scustom\stagline\sstored\sin\sthe\sdatabase.\n\n'
        );
        my @HelpAdmins = ( '\n\n'.$space.'[COLOR=MAROON][U]Administrators[/U][/COLOR]\n\n',
            $space.'[COLOR=RED][B]!Mkick\s[/B]<CCode\pNickname>\s<data>\s<msg>[/COLOR]\s-\sMass\skick\smatching\sccode\sor\snames.\n',
            $space.'[COLOR=RED][B]!Info\s[/B]<Nickname>[/COLOR]\s-\sView\sRbMod\sclient\sinformation.\n',
            $space.'[COLOR=RED][B]!IRC\s[/B]<Command>[/COLOR]\s-\sIssue\sIRC\scommands\sto\sthe\sIRC\sbot.\n',
            $space.'[COLOR=RED][B]!Clean\s[/B][/COLOR]\s-\sClean\sup\sdormant\schannels.\n',
            $space.'[COLOR=RED][B]!Purge\s[/B]<Nickname>[/COLOR]\s-\sRemove\sclient\sfrom\sdatabase\swith\sword\smatch.\n',
            $space.'[COLOR=RED][B]!Purgematch\s[/B]<Nickname>[/COLOR]\s-\sRemove\smultiple\sclients\sfrom\sdatabase\swith\sword\smatch.\n'
        );
        my $Mend = @Help;
        $Mend = join '', @Help;
        &$sub_send( 'sendtextmessage targetmode=1 target='.$clid.' msg='.$Mend.$nl );
        my $Allowed = &rbm_parent::Rbm_check_admin_status($clid,$settings_ref,
                'Exclamation_Triggers_Admin_Group_IDs');
        if (defined $Allowed) {
            $Mend = join '', @HelpAdmins;
            &$sub_send( 'sendtextmessage targetmode=1 target='
                .$clid.' msg='.$Mend.$nl );
        }
    }
    return $gameicons_ref;
}

sub Rbm_GamerChannels {
    my ($CLID,$ChanID,$ChanName,$ChanIcon,$settings_ref,$gameicons_ref,
            $online_ref,$rooms_ref) = @_;
    my $trig;
    my $prevtrig = $online_ref->{$CLID}{'GameRoomName'} || undef;
    --$ActiveGameRooms{$prevtrig}{'CNT'} if defined $prevtrig;

    foreach $trig ( keys %$gameicons_ref ) {
        if ($ChanName and $ChanName =~ /$trig$|^$trig|\\s$trig$|^$trig\\s/i) {
            say 'Found '.$trig;
            $ActiveGameRooms{$trig}{'CNT'} = 0 unless exists $ActiveGameRooms{$trig}{'CNT'};
            $ActiveGameRooms{$trig}{'Icon'} = $ChanIcon unless exists $ActiveGameRooms{$trig}{'Icon'};
            $ActiveGameRooms{$trig}{'ChanID'} = $ChanID;
            ++$ActiveGameRooms{$trig}{'CNT'};

            $online_ref->{$CLID}{'GameRoomName'} = $trig;

            if ($settings_ref->{'Game_Rooms_Activity_Icons_On'} == 1) {
#                &$sub_send('channeledit cid='.$ChanID
#                    .' channel_description=Channel\smarked\sto\sbe\sdeleted\sat\s'.$$timestamp);
                &$sub_send('channeladdperm cid='.$ChanID
                    .' permsid=i_icon_id permvalue='.$gameicons_ref->{$trig}.' permskip=0 permnegated=0' );
            }

            last;
        }
    }
#   Cleanup Inactive Game Rooms
    if ($prevtrig and exists $ActiveGameRooms{$prevtrig}{'Icon'}
            and $ActiveGameRooms{$prevtrig}{'CNT'} <= 0) {
        say 'resetting!';
        &$sub_send('channeladdperm cid='.$ActiveGameRooms{$prevtrig}{'ChanID'}
            .' permsid=i_icon_id permvalue='.$ActiveGameRooms{$prevtrig}{'Icon'}.' permskip=0 permnegated=0' );
        delete $ActiveGameRooms{$prevtrig};
    }
}


sub Rbm_NowPlaying {
    my ($trigger,$invokerid,$settings_ref,$gameicons_ref,$online_ref,
            $NowPlaying_ref,$stopplay,$continue) = @_;
    return unless $invokerid;
    my $DBID = $online_ref->{$invokerid}{'DBID'};
    my ($results_ref,$group_id);
    if ( $stopplay ) {
        my $GameGroupName = $online_ref->{$invokerid}{'NowPlaying'};
        if ( $GameGroupName ) {
            my $GameGroupID   = $NowPlaying_ref->{$GameGroupName}{'GroupID'};
            --$NowPlaying_ref->{$GameGroupName}{'Users'};
            if ($NowPlaying_ref->{$GameGroupName}{'Users'} < 1) {
                &$sub_send('servergroupdel sgid='.$GameGroupID.' force=1');
                delete $NowPlaying_ref->{$GameGroupName};
            }
            else {
                &$sub_send( 'servergroupdelclient sgid='.$GameGroupID
                    .' cldbid='.$DBID );
            }
            delete $online_ref->{$invokerid}{'NowPlaying'};
            return $gameicons_ref unless $continue;
        }
    }
    return $gameicons_ref if exists $online_ref->{$invokerid}{'NowPlaying'}
            or !$trigger;
    my ($orggame,$game,$clean,$tag,$retrieve);
    $trigger =~ s/\\s/ /go;
    $trigger =~ s/^(\S+) \-.*?/$1/oi;
#   Check for rbm_triggers.cf Updates.
    my $File = 'rbm_extras/rbm_triggers.cf';
    my $DateTime = ctime(stat($File)->mtime);
    if ( $DateTime ne ($settings_ref->{'TriggersDate'} || 0) ) {
        $settings_ref->{'TriggersDate'} = $DateTime;
        $gameicons_ref = &rbm_parent::Rbm_LoadConfigs($File);
    }
    my $round2;
    for ( 1..2 ) {
        foreach $orggame ( keys %$gameicons_ref ) {
            if ((!$round2 && $orggame eq $trigger)
                    or ($round2 && ($orggame =~ /$trigger/i || $trigger =~ /$orggame/i))) {
                ($results_ref,$group_id) = undef;
                if ( !exists $NowPlaying_ref->{$orggame}{'Users'} ) {
                    $retrieve = &$sub_cleantext( $orggame );
                    my $search = $$retrieve;
                    $search =~ s/\\s/\\\\s/gi;
                    &$sub_send('servergroupadd name=\"'.substr($$retrieve,0,29).'\" type=1');
                    sleep 0.1;
                    $results_ref = &$sub_query('servergrouplist',$search.'.*?error id=0 msg=ok');
                    ($group_id) = $$results_ref =~ /sgid=(\d+) name\=\"$search/;
                    return $gameicons_ref unless $group_id;
                    &$sub_send( 'servergroupaddperm sgid='.$group_id
                            .' permsid=i_icon_id permvalue='.$gameicons_ref->{$orggame}
                            .' permskip=0 permnegated=0|permsid=i_group_show_name_in_tree permvalue=2 permskip=0 permnegated=0|permsid=i_group_sort_id permvalue=6 permskip=0 permnegated=0' );
                    $NowPlaying_ref->{$orggame}{'Users'} = 1;
                    $NowPlaying_ref->{$orggame}{'GroupID'} = $group_id;
                }
                else {
                    ++$NowPlaying_ref->{$orggame}{'Users'};
                    $group_id = $NowPlaying_ref->{$orggame}{'GroupID'};
                }
                $online_ref->{$invokerid}{'NowPlaying'} = $orggame;
                &$sub_send( 'servergroupaddclient sgid='.$group_id.' cldbid='.$DBID );
                return $gameicons_ref;
            }
        }

        if (!$round2) {
            $round2 = 1;
        }
    }
    return $gameicons_ref;
}

sub Rbm_LastSeen {
    my ($NameLookup,$invokerid,$settings_ref,$online_ref,$FFClients_ref,$rooms_ref,$target,
            $Purge,$targetmode,$chanlookup) = @_;

    my ($TmpName,$TmpDBID,@QueueDelete,@Closest,$Found,$TmpLastChan,$TmpChan,
            $TmpOnline,$ID,$Allowed,$JoinedID,$TmpGroups,@Delete,$CLID,@names);

    if ($chanlookup) {
        my $RoomID;
        foreach $RoomID ( keys %$rooms_ref ) {
            if (lc($rooms_ref->{$RoomID}{'Name'} || '') eq lc($chanlookup)) {
                &$sub_send('sendtextmessage targetmode='
                        .$targetmode.' target='.$target
                        .' msg=Found\smatch\sfor\schannel\s[COLOR=BLUE][B]'
                        .$rooms_ref->{$RoomID}{'Name'}.'[/B][/COLOR]' );
                &$sub_send('sendtextmessage targetmode='
                        .$targetmode.' target='.$target
                        .' msg=Last\sclient:\s[COLOR=RED][B]'.$rooms_ref->{$RoomID}{'UsedBy'}.'[/B][/COLOR]' );
#                say $rooms_ref->{$RoomID}{'UsedBy'};
                $NameLookup = $rooms_ref->{$RoomID}{'UsedBy'};
#                return;
            }
        }
    }
    elsif ($Purge && $Purge == 2) {
        my $Allowed = &rbm_parent::Rbm_check_admin_status($invokerid,$settings_ref,
                'Exclamation_Triggers_Admin_Group_IDs');
        if ($Allowed) {
            my $count = 0;
            my $CLDBID;
            foreach $CLDBID ( keys %$FFClients_ref ) {
                my $TmpName2 = $FFClients_ref->{$CLDBID}{'Nickname'};
                next unless $TmpName2;
                if ($TmpName2 =~ /\Q$NameLookup\E/i ) {
                    ++$count;
                    push(@Delete,$CLDBID);
                    push(@names,$TmpName2);
                }
            }
            return unless $count > 0;
            &$sub_send('sendtextmessage targetmode='
                    .$targetmode.' target='.$target
                    .' msg=Removed\s'.$count.'\sentries\smatching\s[COLOR=BLUE][B]'
                    .$NameLookup.'[/B][/COLOR].' );
            my $names = &$sub_cleantext(join(',\s',@names));
            if (@names) {
                my $truncate = '\[COLOR=RED\]'.substr($$names,0,960).'\[/COLOR\]...';
                $truncate =~ s/\[\/CO\S+[^...]$//oi;
                &$sub_send('sendtextmessage targetmode='
                        .$targetmode.' target='.$target
                        .' msg='.$truncate );
            }
        }
    }
    if ( !$Purge || ($Purge && $Purge == 1)) {
        foreach $CLID ( keys %$FFClients_ref ) {
            $TmpName = $FFClients_ref->{$CLID}{'Nickname'};
            $TmpDBID = $FFClients_ref->{$CLID}{'DBID'};
            $TmpLastChan = $FFClients_ref->{$CLID}{'LastChannel'} || '';
            $TmpOnline = $FFClients_ref->{$CLID}{'ONLINE'};
            $TmpChan = undef;
            next unless $TmpName;

            if (lc($NameLookup) eq lc($TmpName)) {
                $Found = 1;
                if (defined $Purge) {
                    my $Allowed = &rbm_parent::Rbm_check_admin_status($invokerid,
                            $settings_ref,'Exclamation_Triggers_Admin_Group_IDs');
                    if (defined $Allowed) {
                        my $RemovedNick = &$sub_cleantext($TmpName);
#                       !purge
                        &$sub_log( "INFO  \t- \!Purge Trigger     \t- Admin removed DB entry for "
                                .$$RemovedNick.' ('.$TmpDBID.').' );
                        &$sub_send('sendtextmessage targetmode='
                                .$targetmode.' target='.$target
                                .' msg=Removing\sclient\s[COLOR=BLUE][B]'
                                .$TmpName.'[/B][/COLOR].' );
                        push(@Delete,$TmpDBID);
                    }
                    else {
                        &$sub_log( "INFO  \t- \!Purge Trigger     \t- Access Denied for CLID: "
                                .$invokerid.'!' );
                        &$sub_send('sendtextmessage targetmode='
                                .$targetmode.' target='.$target
                                .' msg=Access\sDenied.' );
                    }
                    last;
                }
                &$sub_send('sendtextmessage targetmode='
                        .$targetmode.' target='.$target
                        .' msg=Found\smatch\sfor\s[COLOR=BLUE][B]'
                        .$TmpName.'[/B][/COLOR]' );
                if ( exists $rooms_ref->{$TmpLastChan}{'Name'} ) {
                    $TmpChan = $rooms_ref->{$TmpLastChan}{'Name'};
                }
                unless ($TmpOnline) {
                    my ($time,$ap,$day,$date) = &$sub_proctime(
                            $FFClients_ref->{$CLID}{'LastOnline'} );
                    my $Clean = &$sub_logformat( join('',($$time,$$ap.', '.$$day,$$date)), 1 );
                    my $timestamp = &$sub_cleantext( $$Clean );
                    &$sub_send('sendtextmessage targetmode='
                            .$targetmode.' target='.$target
                            .' msg=Client\sseen:\s[COLOR=NAVY]'
                            .$$timestamp.'[/COLOR]' );
                    my ($LastLoginElapsed) = &rbm_parent::Rbm_ReadSeconds(
                            time - $FFClients_ref->{$CLID}{'LastOnline'}, 1);
                    $$LastLoginElapsed =~ s/^[\\s]*//go;
                    &$sub_send('sendtextmessage targetmode='
                            .$targetmode.' target='.$target.' msg=This\swas\sabout'
                            .$$LastLoginElapsed );
                }
                else {
                     &$sub_send('sendtextmessage targetmode='
                            .$targetmode.' target='.$target.' msg='.$TmpName
                            .'\'s\s[B]Online[/B]!' );
                }
                if ( $TmpChan ) {
                    &$sub_send('sendtextmessage targetmode='
                            .$targetmode.' target='.$target
                            .' msg=Channel\sused:\s[COLOR=RED][B]'.$TmpChan
                            .'[/B][/COLOR]' );
                }
                last;
            }
            elsif ($NameLookup && $NameLookup =~ /\Q$TmpName\E/i
                    || $TmpName =~ /\Q$NameLookup\E/i ) {
                push(@Closest,$TmpName) unless $TmpName eq 'Null';
            }
        }
    }
    if (!$Found && !@Delete && $NameLookup && $NameLookup ne 'Null') {
        &$sub_send('sendtextmessage targetmode='.$targetmode
                .' target='.$target
                .' msg=Couldn\'t\slocate\sthe\sname:\s[COLOR=BLUE][B]'
                .$NameLookup.'[/B][/COLOR]!' );
        if (@Closest) {
            my $names    = &$sub_cleantext(join(',\s',@Closest));
            my $truncate = '\[COLOR=RED\]'.substr($$names,0,1000).'\[/COLOR\]...';
            $truncate    =~ s/\[\/CO\S+[^...]$//oi;
            &$sub_send('sendtextmessage targetmode='.$targetmode
                .' target='.$target.' msg=Found\s[COLOR=NAVY][B]'
                .scalar(@Closest).'[/B][/COLOR]\ssimilar\snames.' );
            &$sub_send('sendtextmessage targetmode='
                .$targetmode.' target='.$target.' msg='.$truncate);
        }
    }
    for (@Delete) {
        delete $FFClients_ref->{$_};
        &$sub_send('clientdbdelete cldbid='.$_);
    }
    @Delete = ();
    &rbm_parent::Rbm_ClientInfoWriteFF();
    return;
}

sub Rbm_IconFill {
    my ($CLID,$online_ref,$settings_ref,$GEOCCode) = @_;
    return if exists $online_ref->{$CLID}{'Clones'}
            or !exists $online_ref->{$CLID}{'DBID'};
    my ($Icon,$CCodeName,$CCodeIcon,$GroupID,$GroupName) = 331178450;

    if ( $GEOCCode ) {
        my $CCodes_ref = &Rbm_CCodes;
        $Icon = $CCodes_ref->{$GEOCCode}{Icon};
        my $RawCCodeName = $CCodes_ref->{$GEOCCode}{Name};
        my $CCodeName = &$sub_cleantext($RawCCodeName);
        return unless $CCodeName;
        $GroupName = substr($$CCodeName,0,26);
    }
    elsif ($online_ref->{$CLID}{'IP'} =~ /^(127\.|192\.168|1\.1\.1|10\.)|^172\.(\d+)/o or ($2 and $2 > 15 and $2 < 32) ) {
        $Icon = 968847211; # Lan cable
        $GEOCCode = 'Ethernet';
        $GroupName = 'Internal\sConnection';
    }
    else {
        $GEOCCode = 'AutoFill';
        $GroupName = 'No\scountry\scode';
    }
    if ( !$Features{'Fill-'.$GEOCCode}{'Users'} ) {
        &$sub_send('servergroupadd name='.substr($GroupName,0,29));
        sleep 0.1;
        my $Search = $GroupName;
        $Search =~ s/\\s/\\\\s/go;
        my $results_ref = &$sub_query('servergrouplist',$Search.'.*?error id=0 msg=ok');
        return if !$results_ref;
        ($GroupID) = $$results_ref =~ /sgid\=(\d+) name\=$Search /;
        return unless $GroupID;
        if ( $settings_ref->{'Autofill_Empty_CCode_Slots_Sort_Order'} !~ /Default/oi ) {
            &$sub_send( 'servergroupaddperm sgid='.$GroupID
                    .' permsid=i_group_sort_id permvalue='.$settings_ref->{'Autofill_Empty_CCode_Slots_Sort_Order'}
                    .' permskip=0 permnegated=0|permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0|permsid=i_icon_id permvalue='.$Icon.' permskip=0 permnegated=0');
        }
        $Features{'Fill-'.$GEOCCode}{'GroupID'} = $GroupID;
        $Features{'Fill-'.$GEOCCode}{'Users'} = 1;
    }
    else {
        ++$Features{'Fill-'.$GEOCCode}{'Users'};
        $GroupID = $Features{'Fill-'.$GEOCCode}{'GroupID'};
    }
    if ( $online_ref->{$CLID}{'Group_Fill'} ) {
        &$sub_send( 'servergroupdelclient sgid='.$online_ref->{$CLID}{'Group_Fill'}
                .' cldbid='.$online_ref->{$CLID}{'DBID'} );
    }
    $GroupName =~ s/\\s/ /go;
    &$sub_log( "INFO  \t- Auto-Fill      \t- Adding ".$online_ref->{$CLID}{'Nickname'}.' to '.$GroupName.' - GroupID: '.$GroupID );
    &$sub_send( 'servergroupaddclient sgid='.$GroupID.' cldbid='
            .$online_ref->{$CLID}{'DBID'} );
    $online_ref->{$CLID}{'Group_Fill'} = $GroupID;
    $online_ref->{$CLID}{'Group_Fill_Used'} = $GEOCCode;
}

sub Rbm_OSDetect {
    my ($CLID,$online_ref,$settings_ref,$groups_ref) = @_;
    return if $settings_ref->{'OS_Detection_On'} eq 0;
    my $os   = $online_ref->{$CLID}{'OS'};
    my $DBID = $online_ref->{$CLID}{'DBID'};
    if ($os eq 'Windows') {
         &$sub_send( 'servergroupaddclient sgid='
            .$groups_ref->{'Group_Windows'}.' cldbid='.$DBID );
    }
    elsif ($os eq 'Linux') {
         &$sub_send( 'servergroupaddclient sgid='
            .$groups_ref->{'Group_Linux'}.' cldbid='.$DBID );
    }
    elsif ($os eq 'OS\sX') {
         &$sub_send( 'servergroupaddclient sgid='
            .$groups_ref->{'Group_Mac'}.' cldbid='.$DBID );
    }
    elsif ($os eq 'iOS') {
         &$sub_send( 'servergroupaddclient sgid='
            .$groups_ref->{'Group_iOS'}.' cldbid='.$DBID );
    }
    elsif ($os eq 'Android') {
         &$sub_send( 'servergroupaddclient sgid='
            .$groups_ref->{'Group_Android'}.' cldbid='.$DBID );
    }
}

sub Rbm_MotdLoadFile {
    my $settings_ref = shift;
    open(my $MOTD, "<rbm_extras/rbm_motd.cf")
        or &$sub_log( "ERROR\t- MOTD      \t- Couldn\'t Load rbm_motd.cf: ".$!);
    my (@SaveMotd,@SaveMotd2);
    my $Redirect;
    while ( <$MOTD> ) {
        chomp;
        next if /[\s\t]*?\#/;
        s/(\[)(\w{2,}[^Start|End])(\])/$1$2$3/goi;
        s/(\[)(\w|.*?\=.*?)(\])/$1$2$3/goi;
        s/[\s]/\\s/go;
        if ( /\[End\]/oi ) {
            $Redirect = 1;
        }
        elsif ( !/\[Start\]/oi && !$Redirect ) {
            push @SaveMotd, $_;
        }
        elsif ( !/\[Start\]/oi && $Redirect ) {
            push @SaveMotd2, $_;
        }
    }
    close $MOTD;
    $settings_ref->{'MOTD1'} = join '\\n', @SaveMotd;
    $settings_ref->{'MOTD2'} = join '\\n', @SaveMotd2;
    return
}

sub Rbm_WelcomeBack {
    my ($CLID,$online_ref,$settings_ref,$rooms_ref,$FFClients_ref,
        $quotes_ref,$randomwords_ref) = @_;
    return if $settings_ref->{'MOTD_On'} eq 0;
#    my $BotName_ref  = &$sub_cleantext(join('',$settings_ref->{'Query_Bot_Name'}));
#    my $BotName2_ref = &$sub_cleantext(join('',$settings_ref->{'Query_Bot_Name2'}));
#   Check for MOTD Updates.
    my $MotdFile = 'rbm_extras/rbm_motd.cf';
    my $DateTime = ctime(stat($MotdFile)->mtime);
    if ( $DateTime ne ($settings_ref->{'MOTDDate'} || 0) ) {
        $settings_ref->{'MOTDDate'} = $DateTime;
        &Rbm_MotdLoadFile( $settings_ref );
    }
    my $Sentence;
    my $Edit = $settings_ref->{'MOTD1'};
    my $DBID = $online_ref->{$CLID}{'DBID'};
    my $Nick = $online_ref->{$CLID}{'Nickname'};
    my $IP = $online_ref->{$CLID}{'IP'};
    my $Ver = $online_ref->{$CLID}{'TSVersion'};
    my $Cntry = $online_ref->{$CLID}{'StatusCountryName'};
    if ( $online_ref->{$CLID}{'CLTotalTime'} ) {
       $Edit = $settings_ref->{'MOTD2'}
    }
#   [ NICK ]
    $Edit =~ s/\[Nick\]/$Nick/goi;
#   [ IP ]
    $Edit =~ s/\[IP\]/$IP/gi;
#   [ VERSION ]
    if ( $online_ref->{$CLID}{'TSVersion'} ) {
        $Edit =~ s/\[Version\]/$Ver/gi;
    } else {
        $Edit =~ s/\[Version\]/Unknown/goi;
    }
#   [ OS ]
    if ( $online_ref->{$CLID}{'OS'} ) {
        $Edit =~ s/\[OS\]/$online_ref->{$CLID}{'OS'}/gi;
    } else {
        $Edit =~ s/\[OS\]/Unknown/goi;
    }
#   [ RandQuote ]
    if ( $Edit =~ /\[RandQuote\]/oi ) {
        my ($RandQuote) = &Rbm_RandomArrayElement(@$quotes_ref);
        my ($Quote) = &$sub_cleantext( join(' ',@$RandQuote) );
        $Edit =~ s/\[RandQuote\]/$$Quote/gi if defined $Quote;
    } else {
        $Edit =~ s/\[RandQuote\]//goi;
    }
#   [ RandWord ]
    if ( $Edit =~ /\[RandWord\]/oi ) {
        my $random    = &Rbm_RandomHashKey($randomwords_ref);
        my $Line      = $randomwords_ref->{$random};
        my $Meaning   = &$sub_cleantext( $Line );
        $random       = &$sub_cleantext( $random );
        $$random      = ucfirst($$random);
        $$Meaning =~ s/\|\\s/\\s\\-\\s/goi;
        $Edit =~ s/\[RandWord\]/\[B\]$$random\[\/B\]\:\\s\\s$$Meaning/gi if defined $Meaning;
    } else {
        $Edit =~ s/\[RandWord\]//goi;
    }
#   [ RandWord ]
    if ( $Edit =~ /\[RandQuoteWord\]/oi ) {
        my $random_number = int(rand(2)) + 1;

        if ($random_number == 1) {
            my $random = &Rbm_RandomHashKey($randomwords_ref);
            my $Line = $randomwords_ref->{$random};
            my $Meaning = &$sub_cleantext( $Line );
            $random = &$sub_cleantext( $random );
            $$random = ucfirst($$random);
            $$Meaning =~ s/\|\\s/\\s\\-\\s/goi;
            $Edit =~ s/\[RandQuoteWord\]/\[B\]$$random\[\/B\]\:\\s\\s$$Meaning/gi if defined $Meaning;
        }
        else {
            my ($RandQuote) = &Rbm_RandomArrayElement(@$quotes_ref);
            my $Quote = &$sub_cleantext( join(' ',@$RandQuote) );
            $Edit =~ s/\[RandQuoteWord\]/$$Quote/goi if defined $Quote;
        }
    } else {
        $Edit =~ s/\[RandQuoteWord\]//goi;
    }
#   [ Country ]
    if ( $Cntry ) {
        $Edit =~ s/\[Country\]/$Cntry/goi;
    } else {
        $Edit =~ s/\[Country\]/Unknown/goi;
    }
#   Message Client our MOTD
    if ( $online_ref->{$CLID}{'CLTotalTime'} ) {
#       [ DNS ]
        if ( $online_ref->{$CLID}{'DNS'} ) {
            $Edit =~ s/\[DNS\]/$online_ref->{$CLID}{'DNS'}/gi;
        } else {
            $Edit =~ s/\[DNS\]/Unknown/goi;
        }
#       [ RANK ]
        if ( $online_ref->{$CLID}{'Rank'} ) {
            $Edit =~ s/\[Rank\]/$online_ref->{$CLID}{'Rank'}/gi;
        } else {
            $Edit =~ s/\[Rank\]/Unknown/goi;
        }
#       [ HOPS ]
        if ( $FFClients_ref->{$DBID}{'Hops'} ) {
            my $hops = $FFClients_ref->{$DBID}{'Hops'};
            $Edit    =~ s/\[Hops\]/$hops/gi;
        } else {
            $Edit =~ s/\[Hops\]/Unknown/goi;
        }
#       [ CONNECTIONS ]
        if ( $online_ref->{$CLID}{'TotalConnects'} ) {
            $Edit =~ s/\[Connections\]/$online_ref->{$CLID}{'TotalConnects'}/gi;
        } else {
            $Edit =~ s/\[Connections\]/0/goi;
        }
#       [ LASTCHAN ]
        if ( $FFClients_ref->{$DBID}{'LastChannel'} ) {
            my $LastChan = $FFClients_ref->{$DBID}{'LastChannel'};
            if ( $rooms_ref->{ $LastChan }{'Name'} ) {
                $LastChan = $rooms_ref->{ $LastChan }{'Name'};
            }
            else {
                $LastChan = '';
            }
            $Edit =~ s/\[LastChan\]/$LastChan/gi;
        } else {
            $Edit =~ s/\[LastChan\]/Unknown/goi;
        }
#       [ FIRSTLOGINTIME ]
        if (  $online_ref->{$CLID}{'Created'} ) {
            my ($time,$ap,$day,$date) = &$sub_proctime( $online_ref->{$CLID}{'Created'} );
            my $Clean                 = &$sub_logformat( ($$time,$$ap.', '.$$day,$$date), 1 );
            my $timestamp             = &$sub_cleantext( $$Clean );
            $Edit =~ s/\[FirstLoginTime\]/$$timestamp/gi;
        } else {
            $Edit =~ s/\[FirstLoginTime\]/0/goi;
        }
#       [ FIRSTLOGINELAPSED ]
        if ( $Edit =~ /\[FirstLoginElapsed\]/oi ) {
            my ($FirstLoginElapsed) = &rbm_parent::Rbm_ReadSeconds(time - $online_ref->{$CLID}{'Created'}, 1);
            $$FirstLoginElapsed     =~ s/^[\\s]*//gi;
            $Edit =~ s/\[FirstLoginElapsed\]/$$FirstLoginElapsed/gi;
        } else {
            $Edit =~ s/\[FirstLoginElapsed\]/0/goi;
        }
#       [ LASTLOGINTIME ]
        if ( $Edit =~ /\[LastLoginTime\]/oi ) {
            my ($time,$ap,$day,$date) = &$sub_proctime( $online_ref->{$CLID}{'LastOnline'} );
            my $Clean = &$sub_logformat( join('',($$time,$$ap.', '.$$day,$$date)), 1 );
            my $timestamp = &$sub_cleantext( $$Clean );
            $Edit =~ s/\[LastLoginTime\]/$$timestamp/gi;
        } else {
            $Edit =~ s/\[LastLoginTime\]/0/goi;
        }
#       [ LASTLOGINELAPSED ]
        if ( $Edit =~ /\[LastLoginElapsed\]/oi ) {
            my ($LastLoginElapsed) = &rbm_parent::Rbm_ReadSeconds(time - $online_ref->{$CLID}{'LastOnline'}, 1);
            $$LastLoginElapsed     =~ s/^[\\s]*//gi;
            $Edit =~ s/\[LastLoginElapsed\]/$$LastLoginElapsed/gi;
        } else {
            $Edit =~ s/\[LastLoginElapsed\]/0/goi;
        }
#       [ MBSENT ]
        if ( $FFClients_ref->{$DBID}{'TotalTx'} ) {
            my $Sent = $FFClients_ref->{$DBID}{'TotalTx'};
            $Sent = &rbm_parent::Rbm_BytesToMBytes( $Sent );
            $Edit =~ s/\[MBSent\]/$Sent/gi;
        } else {
            $Edit =~ s/\[MBSent\]/0/goi;
        }
#       [ MBRECV ]
        if ( $FFClients_ref->{$DBID}{'TotalRx'} ) {
            my $Recv = $FFClients_ref->{$DBID}{'TotalRx'};
            $Recv = &rbm_parent::Rbm_BytesToMBytes( $Recv );
            $Edit =~ s/\[MBRecv\]/$Recv/gi;
        } else {
            $Edit =~ s/\[MBRecv\]/0/goi;
        }

        &$sub_log( "INFO  \t- MOTD          \t- Sent "
            .$online_ref->{$CLID}{'Nickname'}.' the Message Of The Day #2' );
    }
    else {
        &$sub_log( "INFO  \t- MOTD          \t- Sent "
            .$online_ref->{$CLID}{'Nickname'}.' the Message Of The Day #1' );
    }
    if ( $Edit =~ /\[Break\]/oi ) {
        my @Blocks = split /\[Break\]/i, $Edit;
        foreach $Sentence ( @Blocks ) {
            &$sub_send('sendtextmessage targetmode=1 target='.$CLID.' msg='.$Sentence);
        }
    }
    elsif ( length($Edit) >= 1024 ) {
        my @Sentences = $Edit =~ /(.*?\\n)/gco;
        my $length = 0;
        my $Buffer = '';
        foreach $Sentence ( @Sentences ) {
            if ( ($length + length($Sentence)) >= 1024) {
                &$sub_send('sendtextmessage targetmode=1 target='.$CLID.' msg='.$Buffer);
                $length = 0;
                $Buffer = $Sentence;
            }
            else {
                $length = $length + length($Sentence);
                $Buffer = $Buffer.$Sentence;
            }
        }
        if ($Buffer) {
            &$sub_send('sendtextmessage targetmode=1 target='.$CLID.' msg='.$Buffer);
        }
    }
    else {
        &$sub_send('sendtextmessage targetmode=1 target='.$CLID.' msg='.$Edit);
    }
}

sub Rbm_DynamicBanner {
    my ($online_ref,$settings_ref) = @_;
    return if $settings_ref->{'Dynamic_Banner_On'} eq 0;
    my ($time,$Banner,$BannerLink) = time;
#   Handle Banner Images
    if ( !exists $settings_ref->{'BannersIimeStamp'} || (exists $settings_ref->{'BannersIimeStamp'}
        && $settings_ref->{'BannersIimeStamp'} <= ( $time - $settings_ref->{'Dynamic_Banner_URLs_Interval'}) ) ) {
        my @Banners = split /\,/,$settings_ref->{'Dynamic_Banner_URLs'};
        my $Count = 0;
        if ( ( exists $settings_ref->{'BannersCount'}
            && $settings_ref->{'BannersCount'} >= scalar(@Banners) )
            || !exists $settings_ref->{'BannersCount'} ) {
            $settings_ref->{'BannersCount'} = 0;
        }
        foreach $Banner ( @Banners ) {
            $Banner = 'http://'.$Banner unless $Banner =~ /http\:\/\//oi;
            if ( $settings_ref->{'BannersCount'} == $Count ) {
                my $NextRead = &rbm_parent::Rbm_ReadSeconds($settings_ref->{'Dynamic_Banner_URLs_Interval'});
                &$sub_send( 'serveredit virtualserver_hostbanner_gfx_url='
                    .$Banners[$Count].' virtualserver_hostbanner_gfx_interval=0' );
                &$sub_log( "INFO  \t- Dynamic Banner \t- Changing URL: "
                    .$Banner.', Image #'.($Count + 1).'. Next banner in'.$$NextRead.'.' );
                $settings_ref->{'BannersCount'} = $Count + 1;
                last;
            }
            ++$Count;
        }
        $settings_ref->{'BannersIimeStamp'} = $time;
    }
#   Handle Banner Links
    if ( !exists $settings_ref->{'BannerLinksIimeStamp'} || (exists $settings_ref->{'BannerLinksIimeStamp'}
        && $settings_ref->{'BannerLinksIimeStamp'} <= ($time - $settings_ref->{'Dynamic_Banner_URL_Links_Interval'}) ) ) {
        my @BannerLinks = split /\,/, $settings_ref->{'Dynamic_Banner_URL_Links'};
        my $Count = 0;
        if ( ( exists $settings_ref->{'BannerLinksCount'} && $settings_ref->{'BannerLinksCount'} >= scalar(@BannerLinks) )
            || !exists $settings_ref->{'BannerLinksCount'} ) {
            $settings_ref->{'BannerLinksCount'} = 0;
        }
        foreach $BannerLink ( @BannerLinks ) {
            $BannerLink = 'http://'.$BannerLink unless $BannerLink =~ /http\:\/\//oi;
            if ( $settings_ref->{'BannerLinksCount'} == $Count ) {
                my ($NextRead) = &rbm_parent::Rbm_ReadSeconds($settings_ref->{'Dynamic_Banner_URL_Links_Interval'});
                &$sub_send( 'serveredit virtualserver_hostbanner_url='.$BannerLink );
                &$sub_log( "INFO  \t- Dynamic Banner \t- Changing Link URL "
                    .$BannerLink.', Link #'.($Count + 1).'. Next link in'.$$NextRead.'.' );
                $settings_ref->{'BannerLinksCount'} = $Count + 1;
                last;
            }
            ++$Count;
        }
        $settings_ref->{'BannerLinksIimeStamp'} = $time;
    }
}

sub Rbm_RandomHashKey {
    my $wordref = shift;
    my @setups = keys %$wordref;
    return $setups[rand @setups];
}

sub Rbm_RandomArrayElement {
    my (@quotes) = @_;
    my (@quote);
    my $random_number = int(rand(scalar(@quotes))) + 1;
    my  $i;
    for ($i=0; $i < scalar(@quotes); $i++) {
        if ($random_number == $i) {
           push(@quote, $quotes[$i]);
           last;
        }
    }
    return \@quote;
}

sub Rbm_Distance_main {
    my ($lat1, $lon1, $lat2, $lon2, $unit) = @_;
    my $theta = $lon1 - $lon2;
    my $dist = sin(Rbm_Distance_deg2rad($lat1)) * sin(Rbm_Distance_deg2rad($lat2))
            + cos(Rbm_Distance_deg2rad($lat1)) * cos(Rbm_Distance_deg2rad($lat2))
            * cos(Rbm_Distance_deg2rad($theta));
    $dist = Rbm_Distance_acos($dist);
    $dist = Rbm_Distance_rad2deg($dist);
    $dist = $dist * 60 * 1.1515;
    if ($unit eq "K") {
        $dist = $dist * 1.609344;
    }
    elsif ($unit eq "N") {
        $dist = $dist * 0.8684;
    }
    return ($dist);
}

# Get the arccos function using arctan function
sub Rbm_Distance_acos {
    my $rad = shift;
    my $ret = atan2(sqrt(1 - $rad**2), $rad);
    return $ret;
}

# Convert decimal degrees to radians
sub Rbm_Distance_deg2rad {
    my $deg = shift;
    my $pi = atan2(1,1) * 4;
    return ($deg * $pi / 180);
}

# Convert radians to decimal degrees
sub Rbm_Distance_rad2deg {
    my $rad = shift;
    my $pi = atan2(1,1) * 4;
    return ($rad * 180 / $pi);
}

sub Rbm_RankedIconsNames {
    my @RankedIconsNames = (
        'Private\s2','Private\s1st\sClass','Specialist','Corporal','Sergeant',
        'Staff\sSergeant','Sergeant\sFirst\sClass','Master\sSergeant',
        'First\sSergeant','Sergeant\sMajor','Command\sSgt\sMajor',
        'Sgt\sM.\sof\sthe\sArmy','Warrent\sOfficer','Chief\sWO.2',
        'Chief\sWO.3','Chief\sWO.4','Chief\sWO.5','Second\sLieutenant',
        'First\sLieutenant','Captain','Major','Lieutenant\sColonel','Colonel',
        'Brigadier\sGeneral','Major\sGeneral','Lieutenant\sGeneral','General',
        'General\sof\sthe\sArmy'
    );
    return \@RankedIconsNames;
}

sub Rbm_RankedIcons2Names {
    my @RankedIcons2Names = (
        'Private', 'Private\s1st\sClass', 'Lance\sCorporal', 'Corporal',
        'Sergeant', 'Staff\sSergeant', 'Gunnery\sSergeant', 'Master\sSergeant',
        'First\sSergeant', 'Master\sChief', 'Sergeant\sMajor',
        'Third\sLieutenant', 'Second\sLieutenant', 'First\sLieutenant',
        'Captain', 'Group\sCaptain', 'Senior\sCaptain', 'Lieutenant\sMajor',
        'Major', 'Group\sMajor', 'Lieutenant\sCommander', 'Commander',
        'Group\sCommander', 'Lieutenant\sColonel', 'Colonel',
        'Brigadier\sGeneral','Major\sGeneral'
    );
    return \@RankedIcons2Names;
}

sub Rbm_RankedIcons1 {
    my @ranks = (
        367363063, 187404830, 674677796, 299601712, 269151113, 316189951,
        355814946, 197588606, 375648460, 921189634, 225890790, 165415853,
        258481774, 385091808, 301660699, 377981962, 346203521, 302024329,
        198458050, 229928089, 868034217, 369197975, 106321878, 314173261,
        113951932, 270738649, 267116855, 373120703
    );
    return \@ranks;
}

sub Rbm_RankedIcons2 {
    my @ranks = (
        257956289, 116690108, 168838220, 267139651, 425761796, 134118896,
        288837423, 313753556, 341038883, 304770057, 206028208, 308343667,
        244538915, 57454148,  199911607, 928150948, 260696524, 115093994,
        377016425, 218548337, 179581127, 383375919, 140857691, 611495734,
        114654926, 188141747, 147469861
    );
    return \@ranks;
}

sub Rbm_RankedIcons3 {
    my @ranks = (
        946921178, 382585985, 316194638, 246278058, 179900167, 395452608,
        791507518, 402506625, 239391961, 120038743, 392923230, 128335365,
        711200839, 238177141, 195834786, 312381698, 603288926, 616749460,
        313662785, 111047605, 265207895, 271385713, 133056842, 392329125,
        274737270, 151132291, 400292682, 400551038
    );
    return \@ranks;
}

sub Rbm_RankedIcons4 {
    my @ranks = (
        186828957, 696045408, 733091156, 447916222, 418110993, 222344520,
        222809469, 259223312, 775188355, 349928016, 329099818, 140008438,
        181778032, 309003039, 168236270, 323079396, 124376755, 202143719,
        138962472, 316375534, 230007397, 602961433, 993256546, 267392279,
        186932823, 406329749, 789060230, 652159854, 213966723, 535441404,
        349173852, 330199900, 279703527, 151177349, 144657107, 305317254,
        276827219, 273352488, 308055468, 291071868, 299924479, 395619613,
        258374842, 404718116, 246463846, 844496428, 183831055, 141909971,
        331272629, 493961518, 389712207, 127916088, 104116573, 863895254,
        259723550, 313760714, 224401229, 357188720, 140589969, 134882483,
        392902442, 364138794
    );
    return \@ranks;
}

sub Rbm_CloneIcons {
    my @Clones = (
        106070959, 810012614, 223341891, 186527727, 316767875, 170068241,
        395941747, 519827414, 130356967
    );
    return \@Clones;
}

sub Rbm_CloneIcons2 {
    my @Clones = (
        415993416, 160267223, 210589674, 334297011, 244042651, 240046129,
        127245317
    );
    return \@Clones;
}

sub Rbm_HopsIcons5 {
     my @Pak = (
        161458905, 500761621, 673270175, 392332899, 421640794, 865050222,
        381560656, 251720740, 221259677, 107486580, 314350065, 413845757,
        98993342,  188951204, 190456257, 239499582, 366720753, 961833993,
        208856997, 218412902, 670106329, 215249516, 370178327, 76063512,
        147951358, 427578071, 510806457, 134471083, 252862858, 238707712
    );
    return \@Pak;
}

sub Rbm_HopsIcons1 {
     my @Pak = (
        310043009, 232915371, 341084323, 389811393, 251534269, 350778203,
        376625629, 294676542, 299551059, 241955572, 216970128, 365465378,
        228526232, 411849236, 408537790, 408790908, 242884351, 204259190,
        238507370, 292968683, 241136708, 431981489, 336372716, 344284874,
        149458632, 52017529,  128791628, 573995444, 366851226, 363049460,
        39955056
    );
    return \@Pak;
}

sub Rbm_HopsIcons2 {
     my @Pak = (
        403740046, 176103145, 363537584, 231070805, 297187792, 191445294,
        103465950, 171136546, 188307932, 522685642, 370055654, 722791168,
        193279624, 351879639, 267660288, 243661394, 151567792, 553848813,
        274467857, 159372293, 5608013,   417740192, 389691179, 311082519,
        365701400, 257546139, 261856728, 128326801, 682530152, 409464573
    );
    return \@Pak;
}

sub Rbm_HopsIcons3 {
    my @Pak = (
        389335434, 345260453, 133113232, 147508352, 178743822, 138155618,
        562167938, 387800538, 405304515, 127341589, 195411661, 308259858,
        408304563, 228163119, 322167133, 379232395, 406278980, 236994044,
        375533265, 878892680, 303111913, 286654131, 297812126, 225751977,
        274361892, 373223767, 373223767, 225251467, 142083938, 156839594
    );
    return \@Pak;
}

sub Rbm_HopsIcons4 {
    my @Pak = (
        388690243, 380708860, 135229376, 409294126, 258039075, 107190490,
        285857068, 808534382, 222598849, 468387587, 294944756, 10671274,
        431526728, 283274131, 333221252, 116119252, 338948694, 181353303,
        331828520, 174672126, 233805322, 289953643, 158791290, 316208773,
        610181394, 161611416, 764476917, 286151283, 220970395, 791069120
    );
    return \@Pak;
}

sub Rbm_PingIcons {
    my %pingicons = (
        0  => 198529838,
        1  => 112227727,
        2  => 956197567,
        3  => 177808220,
        4  => 215093218,
        5  => 139995299,
        6  => 309441796,
        7  => 427629309,
        8  => 140662899,
        9  => 338263607,
        10 => 246223201,
        11 => 299546617,
        12 => 620355949,
        13 => 176862660,
        14 => 344274093,
        15 => 471375938,
        16 => 202801047,
        17 => 177800277,
        18 => 383404295,
        19 => 494749886,
        20 => 103795443,
        21 => 222713577,
        22 => 372789663,
        23 => 835183591,
        24 => 403732915,
        25 => 175740455,
        26 => 83233348,
        27 => 338340916,
        28 => 157120723,
        29 => 146559717,
        30 => 432703391
    );
    return \%pingicons;
}

sub Rbm_BytesThemeIcons {
    my %bytethemeicons = (
        0  => [
            320890720, 582165278, 338650285, 539742509, 411295128, 296934238,
            140807245, 401727597, 380074600, 103629776, 160770845, 415655536,
            268797294, 262497439, 168834879, 387211691
        ],
        1  => [
            320890720, 582165278, 338650285, 539742509, 411295128, 296934238,
            140807245, 401727597, 380074600, 103629776, 160770845, 415655536,
            268797294, 262497439, 168834879, 387211691
        ],
        2  => [
            235980180, 236938321, 418699707, 229841370, 115277999, 163301446,
            865415864, 158003677, 280104321, 407557413, 471734702, 408361745,
            149421498, 155108880, 669438387, 226724331
        ],
        3  => [
            396387654, 393689164, 195448423, 122126632, 205251887, 572802722,
            104577100, 341987333, 275599932, 216195511, 348488404, 115539527,
            421707977, 135034505, 225082573, 951135032
        ],
        4  => [
            259430845, 400767247, 738061355, 188164857, 212716658, 895922008,
            671720380, 669999667, 309051021, 190094037, 248164850, 127172525,
            408664300, 61199781,  219910729, 386262450
        ],
        5  => [
            189378722, 245844631, 270883172, 764906994, 205077713, 137625220,
            266467094, 346908297, 401583168, 211489521, 327066370, 116254116,
            184521320, 439408924, 126945879, 739234428
        ],
        6  => [
            157623820, 294302532, 115939485, 906190464, 360727272, 246647557,
            108347640, 344927781, 445167783, 339788891, 209162475, 277099129,
            265105438, 270451721, 416624404, 144188476
        ],
        7  => [
            106053762, 136803781, 210457469, 294997631, 180747467, 178909083,
            11048102,  377815582, 45025941,  784319436, 223959176, 240607296,
            123436083, 357751684, 260212294, 429328656
        ],
        8  => [
            133644280, 459981346, 395061875, 286566525, 26405416,  427842109,
            187023900, 234966205, 512415011, 307311445, 293938696, 408326977,
            243633326, 342170451, 353056750, 388744485
        ],
        9  => [
            337403067, 416301443, 946907224, 803284313, 377113489, 351926961,
            780769968, 197148427, 372127396, 253664360, 401626321, 542072290,
            394227323, 250786383, 332540774, 213323604
        ],
        10 => [
            372146598, 337308976, 418139559, 158344919, 160499741, 294032844,
            518070179, 308389745, 897663671, 398950765, 199528956, 126848063,
            167273804, 379413592, 58060962,  419492565
        ],
        11 => [
            106822149, 291592104, 292066479, 176073746, 359576880, 146293548,
            751289953, 121961802, 198092233, 170237591, 245921000, 270045849,
            136409049, 425294768, 119727289, 470103642
        ],
        12 => [
            385138247, 172331820, 290189980, 294666081, 880262728, 160745012,
            96786306,  159087930, 194761439, 245269045, 346660203, 293345625,
            361967889, 736803899, 188403224, 305647863
        ],
        13 => [
            559757774, 301637053, 361911492, 242616638, 372563266, 291004195,
            172315795, 333275680, 417488635, 646102227, 619946962, 400547705,
            782203089, 196638337, 185923814, 380882556
        ],
        14 => [
            352059804, 228929258, 412189176, 391742597, 323912400, 365940161,
            178467818, 173432081, 148638541, 282807777, 299082007, 66286568,
            231067203, 312328614, 262660150, 374589306
        ],
        15 => [
            126412135, 161874463, 382509709, 697043870, 157651991, 815015692,
            124729867, 278281036, 203714342, 338252067, 282355902, 241760352,
            389734636, 195232574, 283783103, 111855036
        ]
    );
    return \%bytethemeicons;
}

sub Rbm_BytesIcons {
    my %byteicons = (
        0  => [
            242417915, 118815440, 347321961, 770852117, 385931581, 303418635,
            108798342, 307099592, 267227216, 164732946, 237008659, 283304965,
            255512489, 735021531, 206743724, 124884949
        ],
        1  => [
            303849800, 230338390, 750374834, 102246462, 396738572, 411507507,
            590957379, 386641215, 143004775, 386271042, 285415135, 335190676,
            273480548, 670699761, 200938161, 107031445
        ],
        2  => [
            246692986, 209194410, 382784367, 320620799, 157251237, 468836206,
            414095189, 129472085, 160166392, 430551064, 321955254, 364562328,
            209987198, 401888989, 170490947, 288870929
        ],
        3  => [
            312877009, 323435676, 891908956, 407797130, 332161475, 429353734,
            126901501, 398151719, 257976344, 168406524, 255530036, 44545229,
            385557658, 327339795, 273620498, 237128019
        ],
        4  => [
            148422747, 367487515, 698023106, 275225777, 221971856, 121881853,
            417205354, 329631922, 219014622, 123185502, 100771351, 209441281,
            405694657, 652226084, 280649003, 450301863
        ],
        5  => [
            461950865, 166090063, 323884951, 240070757, 207818936, 155720937,
            912469691, 588956190, 207403662, 174985983, 313030230, 198756198,
            322267439, 111911979, 401348653, 411855031
        ],
        6  => [
            252434205, 586468059, 309579147, 128820182, 800430235, 317342952,
            368349579, 195125559, 851968204, 109296153, 182820574, 359366170,
            170062091, 232935455, 173694897, 302074527
        ],
        7  => [
            358280762, 26924845,  339291587, 125785128, 290451627, 738996492,
            112525327, 248742708, 555028433, 281483965, 280576832, 111117601,
            390212621, 155019203, 286724663, 183277769
        ],
        8  => [
            110437251, 124429597, 347343214, 170980160, 303364808, 315839188,
            244663741, 613514091, 418228057, 377675490, 151444761, 132244501,
            373651028, 779134362, 265965326, 932827188
        ],
        9  => [
            112721898, 181477923, 424363295, 923027197, 658762544, 975433067,
            233301645, 112025315, 387564883, 146441147, 376762568, 209232960,
            299864195, 337065879, 214641093, 311436288
        ],
        10  => [
            112904724, 211082206, 395275661, 388966437, 17497067,  597873469,
            617443735, 229441714, 717296361, 101005732, 107692131, 407811308,
            204136513, 168482263, 417170903, 347869445
        ],
        11  => [
            382132919, 363232751, 101967285, 251533812, 144084809, 100340704,
            100127923, 177085987, 890195200, 337560619, 252388454, 207000464,
            456824907, 135380356, 197075320, 29789236
        ],
        12  => [
            350832596, 21737998,  325096676, 324881976, 261760227, 541128357,
            330246051, 969203657, 133401408, 348940402, 309320219, 217453740,
            126957009, 73089792,  326627695, 267634405
        ],
        13  => [
            237134688, 166620112, 310662585, 353199236, 270155310, 334104489,
            109773389, 193751860, 246521675, 370861743, 339259441, 374999202,
            168083966, 186946192, 157387503, 192429244
        ],
        14  => [
            370374917, 137339521, 155548590, 100173083, 300368702, 190383799,
            167549121, 157639319, 339855335, 225961681, 183031533, 165189388,
            156962619, 232190875, 244994981, 405862986
        ],
        15  => [
            275087680, 374011393, 366390651, 195826714, 345638235, 131709080,
            258669020, 418452921, 329793813, 610336424, 355150012, 365963215,
            182586395, 177965979, 145112251, 369954760
        ]
    );
    return \%byteicons;
}

sub Rbm_CCodes {
    my %CCodes = (
        AD => { Name => 'Andorra',                          Icon => 495225700 },
        AE => { Name => 'UAE',                              Icon => 729710808 },
        AF => { Name => 'Afghanistan',                      Icon => 227256470 },
        AG => { Name => 'Antigua & Barbuda',                Icon => 264231074 },
        AI => { Name => 'Anguilla',                         Icon => 271412934 },
        AL => { Name => 'Albania',                          Icon => 266561922 },
        AM => { Name => 'Armenia',                          Icon => 209030974 },
        AN => { Name => 'Netherlands',                      Icon => 399321349 },
        AO => { Name => 'Angola',                           Icon => 292008668 },
        AQ => { Name => 'Antarctica',                       Icon => 0         },
        AR => { Name => 'Argentina',                        Icon => 164966870 },
        AS => { Name => 'American Samoa',                   Icon => 234363683 },
        AT => { Name => 'Austria',                          Icon => 241702449 },
        AU => { Name => 'Australia',                        Icon => 308363326 },
        AW => { Name => 'Aruba',                            Icon => 477279392 },
        AX => { Name => 'Aland Islands',                    Icon => 137399114 },
        AZ => { Name => 'Azerbaijan',                       Icon => 252860616 },
        BA => { Name => 'Bosnia',                           Icon => 542752765 },
        BB => { Name => 'Barbados',                         Icon => 37908925  },
        BD => { Name => 'Bangladesh',                       Icon => 156886803 },
        BE => { Name => 'Belgium',                          Icon => 377863488 },
        BF => { Name => 'Burkina Faso',                     Icon => 900747833 },
        BG => { Name => 'Bulgaria',                         Icon => 279215256 },
        BH => { Name => 'Bahrain',                          Icon => 196449300 },
        BI => { Name => 'Burundi',                          Icon => 675039630 },
        BJ => { Name => 'Benin',                            Icon => 192584657 },
        BM => { Name => 'Bermuda',                          Icon => 299152877 },
        BN => { Name => 'Darussalam',                       Icon => 370135850 },
        BO => { Name => 'Bolivia',                          Icon => 421050301 },
        BR => { Name => 'Brazil',                           Icon => 667719659 },
        BS => { Name => 'Bahamas',                          Icon => 160097176 },
        BT => { Name => 'Bhutan',                           Icon => 150139351 },
        BV => { Name => 'Bouvet Island',                    Icon => 276801542 },
        BW => { Name => 'Botswana',                         Icon => 289315615 },
        BY => { Name => 'Belarus',                          Icon => 818015526 },
        BZ => { Name => 'Belize',                           Icon => 307384457 },
        CA => { Name => 'Canada',                           Icon => 273624138 },
        CC => { Name => 'Cocos Islands',                    Icon => 397073152 },
        CD => { Name => 'Congo',                            Icon => 223944790 },
        CF => { Name => 'CAR',                              Icon => 345295982 },
        CG => { Name => 'Congo',                            Icon => 348023176 },
        CH => { Name => 'Switzerland',                      Icon => 234424913 },
        CI => { Name => 'Cote D\'Ivoire',                   Icon => 889784898 },
        CK => { Name => 'Cook Islands',                     Icon => 281858525 },
        CL => { Name => 'Chile',                            Icon => 286206694 },
        CM => { Name => 'Cameroon',                         Icon => 733316597 },
        CN => { Name => 'China',                            Icon => 103830117 },
        CO => { Name => 'Colombia',                         Icon => 106008957 },
        CR => { Name => 'Costa Rica',                       Icon => 88059709  },
        CS => { Name => 'Czechoslovakia',                   Icon => 252719638 },
        CU => { Name => 'Cuba',                             Icon => 385539775 },
        CV => { Name => 'Cape Verde',                       Icon => 128726342 },
        CX => { Name => 'Christmas Island',                 Icon => 128703291 },
        CY => { Name => 'Cyprus',                           Icon => 305993711 },
        CZ => { Name => 'Czech Republic',                   Icon => 398490452 },
        DE => { Name => 'Germany',                          Icon => 425944787 },
        DJ => { Name => 'Djibouti',                         Icon => 287595111 },
        DK => { Name => 'Denmark',                          Icon => 213923004 },
        DM => { Name => 'Dominica',                         Icon => 369549240 },
        DO => { Name => 'Dominican Republic',               Icon => 109507946 },
        DZ => { Name => 'Algeria',                          Icon => 343067672 },
        EC => { Name => 'Ecuador',                          Icon => 424415343 },
        EE => { Name => 'Estonia',                          Icon => 285682223 },
        EG => { Name => 'Egypt',                            Icon => 361441116 },
        EH => { Name => 'Western Sahara',                   Icon => 405944582 },
        ER => { Name => 'Eritrea',                          Icon => 409209456 },
        ES => { Name => 'Spain',                            Icon => 378975178 },
        ET => { Name => 'Ethiopia',                         Icon => 368639550 },
        EU => { Name => 'European Union',                   Icon => 219219442 },
        FI => { Name => 'Finland',                          Icon => 173190239 },
        FJ => { Name => 'Fiji',                             Icon => 264114158 },
        FK => { Name => 'Falkland Islands',                 Icon => 105351300 },
        FM => { Name => 'Micronesia',                       Icon => 266804568 },
        FO => { Name => 'Faroe Islands',                    Icon => 505043869 },
        FR => { Name => 'France',                           Icon => 280123101 },
        FX => { Name => 'France, Metro.',                   Icon => 280123101 },
        GA => { Name => 'Gabon',                            Icon => 208439829 },
        GB => { Name => 'Great Britain',                    Icon => 696821670 },
        GD => { Name => 'Grenada',                          Icon => 243303583 },
        GE => { Name => 'Georgia',                          Icon => 706295086 },
        GF => { Name => 'French Guiana',                    Icon => 280123101 },
        GG => { Name => 'Guernsey',                         Icon => 0 },
        GH => { Name => 'Ghana',                            Icon => 209753578 },
        GI => { Name => 'Gibraltar',                        Icon => 421713461 },
        GL => { Name => 'Greenland',                        Icon => 271750311 },
        GM => { Name => 'Gambia ',                          Icon => 315676736 },
        GN => { Name => 'Guinea',                           Icon => 122847451 },
        GP => { Name => 'Guadeloupe',                       Icon => 170051992 },
        GQ => { Name => 'Equatorial Guinea',                Icon => 113333950 },
        GR => { Name => 'Greece',                           Icon => 329184006 },
        GS => { Name => 'S. Georgia',                       Icon => 667333692 },
        GT => { Name => 'Guatemala',                        Icon => 890260105 },
        GU => { Name => 'Guam',                             Icon => 146981379 },
        GW => { Name => 'Guinea-Bissau',                    Icon => 369980747 },
        GY => { Name => 'Guyana',                           Icon => 262529908 },
        HK => { Name => 'Hong Kong',                        Icon => 316610180 },
        HM => { Name => 'Heard',                            Icon => 308363326 },
        HN => { Name => 'Honduras',                         Icon => 383796375 },
        HR => { Name => 'Croatia',                          Icon => 321577995 },
        HT => { Name => 'Haiti',                            Icon => 411225277 },
        HU => { Name => 'Hungary',                          Icon => 220225951 },
        ID => { Name => 'Indonesia',                        Icon => 428536670 },
        IE => { Name => 'Ireland',                          Icon => 251224607 },
        IL => { Name => 'Israel',                           Icon => 102929215 },
        IM => { Name => 'Isle of Man',                      Icon => 0 },
        IN => { Name => 'India',                            Icon => 241370755 },
        IO => { Name => 'Indian Ocean',                     Icon => 387875496 },
        IQ => { Name => 'Iraq',                             Icon => 387882418 },
        IR => { Name => 'Iran',                             Icon => 775756657 },
        IS => { Name => 'Iceland',                          Icon => 269748198 },
        IT => { Name => 'Italy',                            Icon => 352875026 },
        JE => { Name => 'Jersey',                           Icon => 0 },
        JM => { Name => 'Jamaica',                          Icon => 176315193 },
        JO => { Name => 'Jordan',                           Icon => 403196787 },
        JP => { Name => 'Japan',                            Icon => 268581328 },
        KE => { Name => 'Kenya',                            Icon => 149143287 },
        KG => { Name => 'Kyrgyzstan',                       Icon => 146070751 },
        KH => { Name => 'Cambodia',                         Icon => 297937529 },
        KI => { Name => 'Kiribati',                         Icon => 209906765 },
        KM => { Name => 'Comoros',                          Icon => 389930764 },
        KN => { Name => 'S. Kitts and Nevis',               Icon => 234004114 },
        KP => { Name => 'Korea (North)',                    Icon => 306404348 },
        KR => { Name => 'Korea (South)',                    Icon => 426573749 },
        KW => { Name => 'Kuwait',                           Icon => 147756183 },
        KY => { Name => 'Cayman Islands',                   Icon => 118166069 },
        KZ => { Name => 'Kazakhstan',                       Icon => 381326569 },
        LA => { Name => 'Laos',                             Icon => 742966041 },
        LB => { Name => 'Lebanon',                          Icon => 227707715 },
        LC => { Name => 'Saint Lucia',                      Icon => 104378028 },
        LI => { Name => 'Liechtenstein',                    Icon => 228028510 },
        LK => { Name => 'Sri Lanka',                        Icon => 398444543 },
        LR => { Name => 'Liberia',                          Icon => 345365501 },
        LS => { Name => 'Lesotho',                          Icon => 152143646 },
        LT => { Name => 'Lithuania',                        Icon => 219887667 },
        LU => { Name => 'Luxembourg',                       Icon => 294022788 },
        LV => { Name => 'Latvia',                           Icon => 406686021 },
        LY => { Name => 'Libya',                            Icon => 688005811 },
        MA => { Name => 'Morocco',                          Icon => 971008639 },
        MC => { Name => 'Monaco',                           Icon => 135609401 },
        MD => { Name => 'Moldova',                          Icon => 171016279 },
        ME => { Name => 'Montenegro',                       Icon => 209108722 },
        MF => { Name => 'Saint Martin',                     Icon => 0 },
        MG => { Name => 'Madagascar ',                      Icon => 424711784 },
        MH => { Name => 'Marshall Islands',                 Icon => 288408792 },
        MK => { Name => 'Macedonia',                        Icon => 397399389 },
        ML => { Name => 'Mali',                             Icon => 223164354 },
        MM => { Name => 'Myanmar',                          Icon => 393047576 },
        MN => { Name => 'Mongolia',                         Icon => 324387709 },
        MO => { Name => 'Macau',                            Icon => 869550515 },
        MP => { Name => 'Mariana Islands',                  Icon => 296549866 },
        MQ => { Name => 'Martinique',                       Icon => 133654928 },
        MR => { Name => 'Mauritania',                       Icon => 427115562 },
        MS => { Name => 'Montserrat',                       Icon => 202672948 },
        MT => { Name => 'Malta',                            Icon => 221781701 },
        MU => { Name => 'Mauritius',                        Icon => 250739193 },
        MV => { Name => 'Maldives',                         Icon => 382088379 },
        MW => { Name => 'Malawi',                           Icon => 248277112 },
        MX => { Name => 'Mexico',                           Icon => 161058801 },
        MY => { Name => 'Malaysia',                         Icon => 333985857 },
        MZ => { Name => 'Mozambique',                       Icon => 770332240 },
        NA => { Name => 'Namibia',                          Icon => 274975416 },
        NC => { Name => 'New Caledonia',                    Icon => 593161837 },
        NE => { Name => 'Niger',                            Icon => 199247429 },
        NF => { Name => 'Norfolk Island',                   Icon => 186559136 },
        NG => { Name => 'Nigeria',                          Icon => 388029687 },
        NI => { Name => 'Nicaragua',                        Icon => 168076059 },
        NL => { Name => 'Netherlands',                      Icon => 410041891 },
        NO => { Name => 'Norway',                           Icon => 27680154 },
        NP => { Name => 'Nepal',                            Icon => 352197467 },
        NR => { Name => 'Nauru',                            Icon => 632402627 },
        NT => { Name => 'Neutral Zone',                     Icon => 0 },
        NU => { Name => 'Niue',                             Icon => 156386412 },
        NZ => { Name => 'New Zealand',                      Icon => 390246034 },
        OM => { Name => 'Oman',                             Icon => 283441326 },
        PA => { Name => 'Panama',                           Icon => 376107579 },
        PE => { Name => 'Peru',                             Icon => 161029779 },
        PF => { Name => 'French Polynesia',                 Icon => 192958478 },
        PG => { Name => 'Papua New Guinea',                 Icon => 338306111 },
        PH => { Name => 'Philippines',                      Icon => 405405012 },
        PK => { Name => 'Pakistan',                         Icon => 340372507 },
        PL => { Name => 'Poland',                           Icon => 285096763 },
        PM => { Name => 'St. Pierre',                       Icon => 851536736 },
        PN => { Name => 'Pitcairn',                         Icon => 473512768 },
        PR => { Name => 'Puerto Rico',                      Icon => 375467610 },
        PS => { Name => 'Palestinian Territory',            Icon => 280173502 },
        PT => { Name => 'Portugal',                         Icon => 937664967 },
        PW => { Name => 'Palau',                            Icon => 158497088 },
        PY => { Name => 'Paraguay',                         Icon => 679380976 },
        QA => { Name => 'Qatar',                            Icon => 194844083 },
        RE => { Name => 'Reunion',                          Icon => 280123101 },
        RS => { Name => 'Serbia',                           Icon => 244078698 },
        RO => { Name => 'Romania',                          Icon => 338768888 },
        RU => { Name => 'Russian Federation',               Icon => 157763846 },
        RW => { Name => 'Rwanda',                           Icon => 252089715 },
        SA => { Name => 'Saudi Arabia',                     Icon => 33362792 },
        SB => { Name => 'Solomon Islands',                  Icon => 369835771 },
        SC => { Name => 'Seychelles',                       Icon => 148641280 },
        SD => { Name => 'Sudan',                            Icon => 478900408 },
        SE => { Name => 'Sweden',                           Icon => 311788899 },
        SF => { Name => 'Scotland',                         Icon => 104656361 },
        SG => { Name => 'Singapore',                        Icon => 809706564 },
        SH => { Name => 'St. Helena',                       Icon => 178966409 },
        SI => { Name => 'Slovenia',                         Icon => 396560062 },
        SJ => { Name => 'Svalbard',                         Icon => 276801542 },
        SK => { Name => 'Slovak Republic',                  Icon => 625492271 },
        SL => { Name => 'Sierra Leone',                     Icon => 175244219 },
        SM => { Name => 'San Marino',                       Icon => 624782645 },
        SN => { Name => 'Senegal',                          Icon => 261716386 },
        SO => { Name => 'Somalia',                          Icon => 406802917 },
        SR => { Name => 'Suriname',                         Icon => 171880247 },
        SS => { Name => 'South Sudan',                      Icon => 0 },
        ST => { Name => 'Sao Tome',                         Icon => 292650062 },
        SU => { Name => 'USSR (former)',                    Icon => 0 },
        SV => { Name => 'El Salvador',                      Icon => 295264596 },
        SY => { Name => 'Syria',                            Icon => 409175148 },
        SZ => { Name => 'Swaziland',                        Icon => 179327845 },
        TC => { Name => 'Turks & Caicos',                   Icon => 967372232 },
        TD => { Name => 'Chad',                             Icon => 362531745 },
        TF => { Name => 'French Territories',               Icon => 428465066 },
        TG => { Name => 'Togo',                             Icon => 348006257 },
        TH => { Name => 'Thailand',                         Icon => 53960251  },
        TJ => { Name => 'Tajikistan',                       Icon => 135488456 },
        TK => { Name => 'Tokelau',                          Icon => 110845999 },
        TM => { Name => 'Turkmenistan',                     Icon => 262461334 },
        TN => { Name => 'Tunisia',                          Icon => 741545167 },
        TO => { Name => 'Tonga',                            Icon => 632716282 },
        TP => { Name => 'East Timor',                       Icon => 0 },
        TR => { Name => 'Turkey',                           Icon => 370607123 },
        TT => { Name => 'Trinidad',                         Icon => 309560377 },
        TV => { Name => 'Tuvalu',                           Icon => 399674305 },
        TW => { Name => 'Taiwan',                           Icon => 104500121 },
        TZ => { Name => 'Tanzania',                         Icon => 325886174 },
        UA => { Name => 'Ukraine',                          Icon => 271350152 },
        UG => { Name => 'Uganda',                           Icon => 179890634 },
        UK => { Name => 'United Kingdom',                   Icon => 696821670 },
        UM => { Name => 'U.S.A. Islands',                   Icon => 136140099 },
        US => { Name => 'U.S.A.',                           Icon => 266370988 },
        UY => { Name => 'Uruguay',                          Icon => 25316601 },
        UZ => { Name => 'Uzbekistan',                       Icon => 176242270 },
        VA => { Name => 'Vatican City',                     Icon => 730653405 },
        VC => { Name => 'St. Vincent',                      Icon => 243400126 },
        VE => { Name => 'Venezuela',                        Icon => 175416143 },
        VG => { Name => 'British Islands',                  Icon => 149703715 },
        VI => { Name => 'Virgin Islands',                   Icon => 218670502 },
        VN => { Name => 'Viet Nam',                         Icon => 219228651 },
        VU => { Name => 'Vanuatu',                          Icon => 109945284 },
        WF => { Name => 'Wallis',                           Icon => 317846348 },
        WS => { Name => 'Samoa',                            Icon => 365616972 },
        XK => { Name => 'Kosovo',                           Icon => 0 },
        YE => { Name => 'Yemen',                            Icon => 245410384 },
        YT => { Name => 'Mayotte',                          Icon => 100073622 },
        YU => { Name => 'Serbia',                           Icon => 0 },
        ZA => { Name => 'South Africa',                     Icon => 389572971 },
        ZM => { Name => 'Zambia',                           Icon => 202365049 },
        ZR => { Name => 'CD Congo',                         Icon => 0 },
        ZW => { Name => 'Zimbabwe',                         Icon => 420692818 }
    );
    return \%CCodes;
}

sub Rbm_Temps {
    my %Temps = (
        -66 => 223616514,
        -33 => 191766669,
        -32 => 207993406,
        -31 => 847791705,
        -30 => 287874372,
        -29 => 274311386,
        -28 => 307734601,
        -27 => 307772032,
        -26 => 385603063,
        -25 => 349749851,
        -24 => 66458640,
        -23 => 356965164,
        -22 => 362883955,
        -21 => 274428937,
        -20 => 220280878,
        -19 => 738528371,
        -18 => 196608884,
        -17 => 331506351,
        -16 => 284676413,
        -15 => 124916683,
        -14 => 134263998,
        -13 => 264167674,
        -12 => 326062053,
        -11 => 294182667,
        -10 => 183718293,
        -9  => 349531006,
        -8  => 220325468,
        -7  => 377884326,
        -6  => 450593278,
        -5  => 241900549,
        -4  => 273844416,
        -3  => 272541828,
        -2  => 366581863,
        -1  => 377337929,
         0  => 430170732,
         1  => 257481990,
         2  => 344181883,
         3  => 817715498,
         4  => 381234113,
         5  => 363955962,
         6  => 182455284,
         7  => 178637311,
         8  => 330416316,
         9  => 245957286,
         10 => 121221298,
         11 => 326528683,
         12 => 251089063,
         13 => 333337948,
         14 => 385518705,
         15 => 186299800,
         16 => 782784972,
         17 => 183624200,
         18 => 198648220,
         19 => 358631548,
         20 => 230074777,
         21 => 310300940,
         22 => 421984644,
         23 => 311140953,
         24 => 361003229,
         25 => 123905869,
         26 => 104795835,
         27 => 375901409,
         28 => 106159281,
         29 => 122314296,
         30 => 387430569,
         31 => 838405314,
         32 => 167976641,
         33 => 426051806,
         34 => 57275696,
         35 => 201771212,
         36 => 940537052,
         37 => 855572630,
         38 => 441973800,
         39 => 145044860,
         40 => 531214562,
         41 => 318369602,
         42 => 104306646,
         43 => 318800388,
         44 => 702498026,
         45 => 112489743,
         46 => 112489743,
         47 => 192902650,
         48 => 195425607,
         49 => 486674529,
         50 => 344197140,
         51 => 330756199,
    );
    return \%Temps;
}

1;
