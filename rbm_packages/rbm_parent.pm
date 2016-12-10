package rbm_parent;

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
use rbm_features;
use Time::HiRes qw( sleep );
use File::stat qw(:FIELDS);
use IO::Socket();
use IO::Select();
use LWP::Simple;
use Encode;

our ($TotalClients,$PingCount,$PollTick,$MODreceived,$MODsent,$Version,$Logging,
        $Debug,$OSType,$ShellColor,$GoodBye,$Booted,$BootFinished,$gi,
        $ChanAdminID) = (0,0,1,0,0,'3.2.4',undef,0);
my ( $nl,$sub_trigs,$sub_Weather,$sub_GeoLookup,$sub_log,$sub_send,$sub_query,
        $sub_dbread,$sub_dbwrite,$sub_proctime,
        $sub_cleantext,$sub_logformat,$sub_exemptguest,$sub_exempt,$sub_chflood,
        $sub_chdel,$sub_chPunish,$sub_chDelPunish,$sub_record,$sub_idlemove,$sub_clstatus,
        $sub_grpprot,$sub_tagline,$sub_automove,$sub_rbllookup,$sub_clonedet,
        $sub_wback,$sub_osdetect,$sub_ranking,$sub_iconfill,$sub_dnslookup,
        $sub_trace,$sub_NowPlaying,$sub_countries,$sub_temperatures,$LOG,$sock,
        $FFCLList,%NowPlaying,%online,%FFClients,%PartMsgs,$randomwords_ref,
        $badwords_ref,$q_responses_ref,$quotes_ref,$settings_ref,$BotName_ref,
        $groups_ref,$Cnt,%rooms,$sockselect,$gameicons_ref,$goodbyes_ref,
        $channellist_ref,$TempSockCache )
    = ( "\n",\&Rbm_Triggers,\&Rbm_WeatherLookup,\&Rbm_CountryRegionCity,\&Rbm_Log,
        \&Rbm_TSSend,\&Rbm_TS3Query,\&Rbm_ClientInfoReadFF,
        \&Rbm_ClientInfoWriteFF,\&Rbm_ProcessTime,\&Rbm_Clean,\&Rbm_LogFormat,
        \&Rbm_CheckGuestExemptions,\&Rbm_CheckExemptions,
        \&rbm_features::Rbm_ChannelFloodQueue,\&rbm_features::Rbm_ChannelDelete,
        \&rbm_features::Rbm_ChannelPunish,
        \&rbm_features::Rbm_ChannelDelPunish,\&rbm_features::Rbm_Recording,
        \&rbm_features::Rbm_IdleMover,\&rbm_features::Rbm_ClientStatus,
        \&rbm_features::Rbm_GroupProtect,\&rbm_features::Rbm_TagLine,
        \&rbm_features::Rbm_AutoMove,\&rbm_features::Rbm_RBLLookup,
        \&rbm_features::Rbm_CloneDetection,\&rbm_features::Rbm_WelcomeBack,
        \&rbm_features::Rbm_OSDetect,\&rbm_features::Rbm_Ranking_Process,
        \&rbm_features::Rbm_IconFill,\&rbm_features::Rbm_DNSLookup,
        \&rbm_features::Rbm_Traceroute,\&rbm_features::Rbm_NowPlaying,
        \&rbm_features::Rbm_CCodes,\&rbm_features::Rbm_Temperatures);
my ($SocketCounter,@BOTCLIDs,$FFChans,$QuiteBoot) = 0;
my $BadWordsFile = 'rbm_extras/rbm_badwords.cf';
my $CCodeNames_ref = &$sub_countries;

# Cleanup and shutdown Mod.
sub Rbm_Cleanup {
    if ($Booted) {
        &Rbm_Disconnect;
        &$sub_dbwrite;
        &$sub_log("INFO \t- SHUTDOWN       \t\- Good Bye.", 1);
    }
    close($LOG) if defined $LOG;
    $TotalClients = 0;
    $Booted = undef;
    $LOG = undef;
    sleep 0.3;
    kill 9;
    kill('TERM', 0);
    exit(0);
}

# Disconnect Socket only.
sub Rbm_Disconnect {
    &$sub_log("INFO \t- DISCONNECT        \t\- Dropping socket connection!", 1);
    return unless $Booted;
    unless (defined $QuiteBoot) {
        &$sub_send('sendtextmessage targetmode=3 target=1 msg=[COLOR=RED][B]Shutting\sDown![/B][/COLOR]');
        &$sub_send('sendtextmessage targetmode=3 target=1 msg=[COLOR=NAVY][B]Good\sBye.[/B][/COLOR]');
    }
    &$sub_send('quit');
    $sock->shutdown(1);
    close($sock);
}

# Clean messages for TS3 or Console.
sub Rbm_Clean {
    my ($raw,$KeepSpaces,$Remove) = @_;
    return unless defined $raw;
    $raw =~ s/[\r\t\/]+//go;
    $raw =~ s`\&`\\&`go;
    unless (defined $KeepSpaces) {
        $raw =~ s/ /\\s/go;
    }
    $raw =~ s/\\s/ /go if defined $Remove;
    $raw = 0 unless defined $raw;
    return \$raw;
}

# Capture log messages from RbMod code.
sub Rbm_Log {
    my ($msg,$Override) = @_;
    my ($time,$ap,$day,$date) = &$sub_proctime();
    $msg =~ s/\\s/ /go;
    if ((defined $Debug && $Debug == 1) || $Override) {
        my $line2 = &$sub_logformat($$day.$$time.$$ap);
        print "\r".(" " x 90);
        if ($OSType !~ /Win/io) {
            print "\r".$ShellColor.$$line2." \t".$msg.$nl;
        }
        else {
            if (defined $Override) {
                print "\r".$ShellColor.$$line2." \t".$msg.$nl;
            }
            else {
                print "\r".$ShellColor.$$line2." \t".$msg.$nl;
            }
        }
    }
    if ( defined $Logging && $Logging == 1 and $LOG ) {
        my $line = &$sub_logformat($$date.' '.$$day.$$time.$$ap." \t");
        syswrite $LOG, $$line.$msg.$nl or die "ERROR \t- Writing to Log: ".$!;
    }
}

# Communication with TS3 server, Send And Forget.
sub Rbm_TSSend {
    my ($Send,$socket) = @_;
    $sock = $socket if defined $socket;
    return unless defined $sock;
#    say $Send;
    my $Bytes_Sent = syswrite $sock, $Send.$nl;
    if ( defined $Debug && $Debug != 0 && defined $Bytes_Sent) {
        $MODsent = $MODsent + $Bytes_Sent;
    }
}

# Main communication with TS3 server, Send And Receive.
sub Rbm_TS3Query {
    my ($cmd,$Waitfor,$socket) = @_;
#    $cmd =~ s/\|/\\p/go;
    $sock = $socket if defined $socket;
    return unless defined $sock;
    my ($bytes_read,$Buffer,$Cached,$Tempsock,@socks) = (0,'');
#    say $cmd;
    my $Bytes_Sent = syswrite $sock, $cmd.$nl;
    $MODsent = $MODsent + ($Bytes_Sent || 0) if $Debug != 0;
    while(1) {
        if (!defined $socket && (@socks =
                $sockselect->can_read($settings_ref->{'Query_Connect_Retry_Delay'}))) {
            $Tempsock = shift(@socks);
        }
        else {
            $Tempsock = $socket;
        }
        if (defined $Tempsock) {
            $bytes_read = sysread($Tempsock, $Buffer, 5000*1024);
            if ( defined $bytes_read && $bytes_read != 0 ) {
                $SocketCounter = 0 if $SocketCounter > 0;
                $MODreceived = $MODreceived + $bytes_read;
                $Buffer = &$sub_cleantext($Buffer, 1);
                $$Buffer =~ s/[\[\]]+//go if $cmd eq 'serverinfo';
                $$Buffer =~ s/[\(\)]+//go if $cmd eq 'servergrouplist';
                $Cached = $Cached.$$Buffer;
                &$sub_trigs($$Buffer) unless $settings_ref->{'Exclamation_Triggers_On'} eq 0;
#                say $$Buffer;
                if ( $Cached =~ /error id=([^0]\d+) msg=(\S+)/so ) {
                    my $error = $1;
                    my $msg = $2;
                    $msg =~ s/\\s/ /gi;
                    if ($Cached !~ /(invalid\\sclientID|invalid\\schannelID|channelname\\sis\\salready|already\\smember\\sof\\schannel|duplicate\\sentry|channel\\snot\\sempty)/so) {
                        &$sub_log("ERROR\t- TS3 Query         \t- TS3 Error ID: ".$error.' Msg: '.$msg, 1);
                    }
                    if ( $Cached =~ /(Server\\sShutdown|server\\sis\\snot\\srunning|you\\sare\\sbanned|connection\\sfailed)/sio ) {
                        &Rbm_Cleanup;
                        return;
                    }
                    elsif ( $Cached =~ /invalid\\sclient/so and $Waitfor and $Waitfor =~ /connection_client_ip/o ) {
                        return undef;
                    }
                    elsif ( $Cached =~ /invalid\\schannel|channelname\\sis\\salready|convert/so and $Waitfor and $Waitfor =~ /cid\=/o ) {
                        return undef;
                    }
                    elsif ( $Cached =~ /channel\\snot\\sempty/so ) {
                        return undef;
                    }
                    elsif ( $Cached =~ /missing\\srequired\\sparameter|invalid\\sparameter\\ssize/so ) {
#                        say $Cached;
                    }
                }
                $Cached =~ s/[\(\)]//o;
                if ( defined $Waitfor ) {
                    if ( $Cached =~ /$Waitfor.*?\n/s ) {
                        return \$Cached;
                    }
                    elsif ( $Cached !~ /$Waitfor/s ) {
                        $bytes_read = 0;
#                        sleep 0.001;
                        next;
                    }
                }
                elsif ( $Cached =~ /\n/so ) {
                    return \$Cached;
                }
#                sleep 0.001;
                next;
            }
            else {
#                &$sub_trigs($Cached)
#                    unless $settings_ref->{'Exclamation_Triggers_On'} eq 0;
                return \$Cached if defined $Cached;
                return undef;
            }
        }
        else {
            close $Tempsock if defined $Tempsock;
            ++$Cnt;
            if ($SocketCounter <= $settings_ref->{'Query_Connect_Retry'}) {
                ++$SocketCounter;
                &$sub_log("INFO  \t- TS3 Query        \t- Couldn\'t read from socket\, retry attempt \#".$SocketCounter, 1)
                        if $SocketCounter > 1;
                return undef;
            }
            else {
                $SocketCounter = 0;
            }
            &$sub_log("INFO  \t- TS3 Query  \t- Attempting to reconnect... ".$Cnt.'/'.$settings_ref->{'Query_Connect_Retry'}. ' retries.', 1);
            sleep $settings_ref->{'Query_Connect_Retry_Delay'};
            &Rbm_Cleanup if $Cnt >= $settings_ref->{'Query_Connect_Retry'};
            &Rbm_Connect;
            &Rbm_CleanGroups;
            &Rbm_Instanceinfo;
            &Rbm_AddGroups;
            %online = ();
            return undef;
        }
    }
}

# Manipulate system timestamps to readable format
sub Rbm_ProcessTime {
    my $timestamp = shift;
    my $time;
    if ($timestamp) {
        $time = $timestamp;
    }
    else {
        $time = time;
    }
    my @months = qw`January February March April May June July August September
        October November December`;
    my @days = qw`Sunday Monday Tuesday Wednesday Thursday Friday Saturday`;
    my @ext = qw`st nd rd th`;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$dst) = localtime($time);
    my $ap;
    $ap = '_AM' if $hour < 12;
    $ap = '_PM' if $hour > 11;
    if ( $sec < 10 && $sec >= 0 ) { $sec = '0'.$sec; }
    if ( $min < 10 ) { $min = '0' . $min; }
    if ( $hour > 12 ) { $hour = $hour - 12; }
    elsif ( $hour == 0 ) { $hour = 12; }
    if ( $mday =~ /^(1|21|31)$/o ) { $mday = $mday . $ext[0]; }
    elsif ( $mday =~ /^(2|22)$/o ) { $mday = $mday . $ext[1]; }
    elsif ( $mday =~ /^(3|23)$/o ) { $mday = $mday . $ext[2]; }
    else  { $mday = $mday . $ext[3]; }
    $year    = $year + 1900;
    my $day  = $days[$wday].'_';
    my $date = $months[$mon].'_'.$mday.'_'.$year;
    $time    = $hour.'.'.$min.'.'.$sec;
    return (\$time,\$ap,\$day,\$date);
}

# Manipulate timestamps to remaining time, readable format(s)
sub Rbm_ReadSeconds {
    my ($sec,$TSFormat,$RBRank) = @_;
    my $days = int($sec/(24*60*60));
    my $hours = ($sec/(60*60))%24;
    my $mins = ($sec/60)%60;
    my $secs = $sec%60;
    my ($b,$ub,$extended,$word_days,$word_hours,$word_minutes,$word_seconds,
            $string) = (' ',' ','','days','hours','minutes','seconds');
    $word_days = 'day' if ($days == 1);
    $word_hours = 'hour' if ($hours == 1);
    $word_minutes = 'minute' if ($mins == 1);
    $word_seconds = 'second' if ($secs == 1);
    if ($secs < 6 && $days < 1 && $hours < 1
            && $mins < 1 && $TSFormat && !$RBRank) {
        $extended = '\sago?';
    }
    elsif ($TSFormat && !$RBRank) {
        $extended = '\sago.';
    }
    if ( $TSFormat ) {
        $b = '\s[B]\s';
        $ub = '\s[/B]\s';
    }
    if ( $days > 0 ) {
        $string = $b.$days.$ub.$word_days.$b.$hours.$ub.$word_hours.$b.$mins
                .$ub.$word_minutes.$b.$secs.$ub.$word_seconds.$extended;
    }
    elsif ( $hours > 0 && $mins == 0 && $secs == 0) {
        $string = $b.$hours.$ub.$word_hours.$extended;
    }
    elsif ( $hours > 0 && $secs == 0) {
        $string = $b.$hours.$ub.$word_hours.$b.$mins.$ub.$word_minutes.$extended;
    }
    elsif ( $hours > 0 && $mins == 0) {
        $string = $b.$hours.$ub.$word_hours.$b.$secs.$ub.$word_seconds.$extended;
    }
    elsif ( $hours > 0 ) {
        $string = $b.$hours.$ub.$word_hours.$b.$mins.$ub.$word_minutes.$b.$secs
                .$ub.$word_seconds.$extended;
    }
    elsif ( $mins > 0 && $secs == 0) {
        $string = $b.$mins.$ub.$word_minutes.$extended;
    }
    elsif ( $mins > 0 ) {
        $string = $b.$mins.$ub.$word_minutes.$b.$secs.$ub.$word_seconds.$extended;
    }
    else {
        $string = $b.$secs.$ub.$word_seconds.$extended;
    }
    return \$string;
}

# Console colors
sub Rbm_CheckUserColor {
    my $UserColor  =  shift;
    my $Color;
    my %ColorNames = ( "Red", 31,
                       "Green", 32,
                       "Yellow", 33,
                       "Blue", 34,
                       "Magenta", 35,
                       "Cyan", 36,
                       "White", 37,
                     );
    foreach $Color (keys %ColorNames) {
        if ( $Color =~ /$UserColor/i ) {
            if ($OSType !~ /Win/oi) {
                 $ShellColor = "\033[".$ColorNames{$Color}.'m';
            }
            else {
                 $ShellColor = "\e[1;".$ColorNames{$Color}.'m';
            }
        }
    }
}

# Make New log upon bootup.
sub Rbm_MKLogs {
    my ($error,$tstamp,$settings_ref) = @_;
    sub newdir {
        my $tstamp2 = shift;
        say "WARN  \t- Logs Directory   \t- Cannot find rbm_logs\/ directory\! I\'ll create it now.";
        my $dirname = "rbm_logs\/rbm_logs";
        mkdir $dirname, 0755 or die
            "ERROR  \t- Logs Directory   \t- Creating Logs directory: ".$nl.$!;
        say "OK    \t- Logs Directory   \t- rbm_logs/logs/ directory created.";
        open($LOG, "<rbm_logs/rbmod_".$$tstamp2)
            or die "ERROR   \t- Loading Log file: ".$!.$nl;
    }
    open($LOG, "<rbm_logs/rbmod_".$$tstamp)
            or &newdir($tstamp);
    flock($LOG, 2);
}

# Clean stagnat logs, older than settings cache variable.
sub Rbm_CleanLogs {
    return if $settings_ref->{'Logging_On'} eq 0;
    my $tik = 0;
    &$sub_log("LOAD  \t- Logs Cleaner     \t- Stagnant Log Cleaner...", 1);
    my $timenow = localtime(time);
    opendir(DIR, 'rbm_logs/')
            or die "ERROR  \t- Logs Cleaner     \t- Stagnant Log Cleaner couldn't open directory ".$!;
    while(my $oldlog = readdir(DIR)) {
        next if $oldlog =~ /^\.\.?/o;
        if(-d "$oldlog"){
            next;
        }
        else {
            my ($timestamp) = $oldlog =~ /(\d{9,})/o;
            next unless (defined $timestamp);
            if ($timestamp < (time - $settings_ref->{'Logging_Cache_Time'}) ) {
                ++$tik;
                unlink('rbm_logs/'.$oldlog);
                &$sub_log("OK  \t- Logs Cleaner     \t- Removed old log: ".$oldlog, 1);
            }
        }
    }
    if ($tik > 0) {
        &$sub_log("DONE  \t- Logs Cleaner     \t- Removed ".$tik.' old log files.', 1);
    }
    else {
        &$sub_log("OK   \t- Logs Cleaner     \t- Nothing to cleanup.", 1);
    }
    closedir(DIR);
    return;
}

# Change RbMod log / Debug format accordingly
sub Rbm_LogFormat {
    my ($raw,$cleanTS3) = @_;
    if ( $cleanTS3 ) {
        $raw =~ s/\_/ /go;
        $raw =~ s/\-/\, /go;
        $raw =~ s/\./\:/go;
        $raw =~ s/ \\s/ /go;
        $raw =~ s/\\s / /go;
        $raw =~ s/\\s/ /go;
        $raw =~ s/ /\\s/go;
    }
    else {
        $raw =~ s/\_/ /go;
        $raw =~ s/\-/\, /go;
        $raw =~ s/\./\:/go;
    }
    return \$raw;
}

# Load in Configuration Files
sub Rbm_LoadConfigs {
    my ($file,$Bootup) = @_;
    my (@tmp2,%tmp,@row) = ();
    if ($file =~ /rbm_settings.cf|rbm_funwords.cf|rbm_triggers.cf/so) {
        open(CONFIG,"<$file") or die $!;
        flock(CONFIG, 2);
        while ( <CONFIG> ) {
            s/\s+$//o;
            (@row) = $_ =~ /^([^\#].*?)[\s]+?\=(.*?)$/si;
            next unless $row[0];
            $row[1] =~ s/^\s{1,}//o;
            $row[1] =~ s/\#.*?$//o;
            $row[1] =~ s/^[No|Off][^\S\s]/0/io;
            $row[1] =~ s/^[Yes|On][^\S\s]/1/io;
            if ( @row ) {
                $row[1] =~ s/\t|\#|\n|\r|\s+$//go;
                $row[1] =~ s/\s{2,}/\\s/go;
                $tmp{$row[0]} = $row[1];
            }
        }
        flock(CONFIG, 8);
        close(CONFIG);
    }
    elsif ($file =~ /rbm_badwords.cf|rbm_quotes.cf|rbm_botresponses.cf|rbm_goodbye.cf/so) {
        open(CONFIG, "<$file")
            or &$sub_log("ERROR  \t- Config Files   \t- Loading ".$file.' file!', 1);
        flock(CONFIG, 2);
        while ( <CONFIG> ) {
            s/\s+$//o;
            push(@tmp2,$_);
        }
        flock(CONFIG, 8);
        close(CONFIG);
    }
    if (@tmp2) {
        &$sub_log("OK    \t- Config Files   \t- Loaded ".scalar(@tmp2)
            .' rows from '.$file.'.', 1);
        return \@tmp2;
    }
    unless ( $Bootup ) {
        my $size = keys %tmp;
        &$sub_log("OK    \t- Config Files   \t- Loaded ".$size.' rows from '
            .$file.'.', 1);
    }
    return \%tmp;
}

# Add RbMod groups
sub Rbm_AddGroups {
    my ($cnt,@bot_names,$sticky_group,$bot_group,$win_group,$lin_group,
        $mac_group,$ios_group,$android_group,$results_ref,$guestsID,$NewGuestID,
        $botname) = 0;
    unless (defined $QuiteBoot) {
        &$sub_send('sendtextmessage targetmode=3 target=1 msg=[COLOR=BLUE][B]Adding\sclients\sto\sRbMod\sfeatures...[/B][/COLOR]');
    }
    push @bot_names, 'Abnormal';
    if ( $settings_ref->{'Channel_Flood_Detection_On'} ne 0
            or $settings_ref->{'Channel_Punish_Detection_On'} ne 0 ) {
        push @bot_names, 'Sticky';
    }
    else {
        push @bot_names, '';
    }
    if ( $settings_ref->{'OS_Detection_On'} ne 0 ) {
        push @bot_names, 'Windows','Linux','OS\sX','iOS','Android';
    }
    else {
        push @bot_names,'','','','','';
    }
    sleep 0.2;
    if ( $settings_ref->{'Guest_Group_Name'} !~ /default/oi ) {
        $settings_ref->{'Guest_Group_Name'} = 'GuestClient'
                if $settings_ref->{'Guest_Group_Name'} eq 'Guest';
        my ($botname) = &$sub_cleantext($settings_ref->{'Guest_Group_Name'});
        $bot_names[0] = $$botname;
    }
    if ($settings_ref->{'Guest_Group_ID'} !~ /default/oi) {
        $guestsID = $settings_ref->{'Guest_Group_ID'};
    }
    elsif ($settings_ref->{'Guest_Group_ID'} =~ /default/oi) {
        $results_ref = &$sub_query('serverinfo',
                'virtualserver_default_server_group=\d+.*?error id=0 msg=ok');
        ($guestsID) = $$results_ref =~ /virtualserver_default_server_group=(\d+)/oi
                if defined $results_ref;
    }
    unless ($guestsID) {
        &$sub_log("ERROR  \t- Group Creator    \t- Couldn\'t find your Guest Group ID! - Please check your settings and try again.", 1);
        &Rbm_Cleanup();
    }
    &$sub_send('servergroupcopy ssgid='.$guestsID
            .' tsgid=0 name='.$bot_names[0].' type=1');
    sleep 0.2;
    $results_ref = &$sub_query('servergrouplist','namemode.*?error id=0 msg=ok');
    my $search = $bot_names[0];
    $search =~ s/\\s/\\\\s/go;
    ($NewGuestID) = $$results_ref =~ /sgid\=(\d+) name\=$search /;
    $guestsID =~ s/[\s]//go;
    if ($NewGuestID) {
        if ( $settings_ref->{'Guest_Group_Sort_Order'} !~ /Default/io ) {
            &$sub_send( 'servergroupaddperm sgid='.$NewGuestID
                .' permsid=i_group_sort_id permvalue='
                .$settings_ref->{'Guest_Group_Sort_Order'}
                .' permskip=0 permnegated=0' );
        }
        &$sub_log("OK    \t- Group Creator     \t- Copied Guest Group "
            .$bot_names[0].' with ID: '.$guestsID.' To New Group ID: '
            .$NewGuestID, 1);
        $groups_ref->{'Group_Guest'} = $NewGuestID;
    }
    else {
        &$sub_log("ERROR  \t- Group Creator    \t- Couldn\'t find "
            .$bot_names[0].' ID!', 1);
        &Rbm_Cleanup;
    }
    foreach $botname (@bot_names) {
        next unless $botname =~ /\S+/o;
        $botname =~ s` `\\s`go;
        &$sub_send('servergroupadd name='.substr($botname,0,29).' type=1')
                unless $bot_names[0] eq $botname or $botname !~ /\S+/o;
        sleep 0.05;
    }
    sleep 0.2;
    $results_ref = &$sub_query('servergrouplist', 'namemode.*?error id=0 msg=ok');
    &$sub_log("LOAD  \t- Group Creator     \t- Checking Rb \'Groups\' on your TS3 server...",1);
    my ($ClonePack_ref) = &rbm_features::Rbm_CloneIcons2;
    foreach $botname (@bot_names) {
        my $find_rbot_grp;
        $botname =~ s` `\\s`go;
        if ($bot_names[0] ne $botname && $settings_ref->{'OS_Detection_On'} ne 0) {
            my $search = $botname;
            $search =~ s/\\s/\\\\s/go;
            my ($group_id) = $$results_ref =~ /sgid=(\d+) name=$search /;
            unless ($results_ref && $$results_ref !~ /name=$search /) {
                for (1..10) {
                    $results_ref = &$sub_query('servergrouplist',
                            $search.'.*?error id=0 msg=ok');
                    last if defined $results_ref && $$results_ref =~ /$search/;
                    sleep 0.2;
                }
            }
            if ($botname eq $bot_names[1] and
                    ($settings_ref->{'Channel_Flood_Detection_On'} ne 0
                    or $settings_ref->{'Channel_Punish_Detection_On'} ne 0)) {
                $sticky_group = $group_id;
                $groups_ref->{'Group_Sticky'} = $group_id;
                &$sub_send( 'servergroupaddperm sgid='.$sticky_group.
                    ' permsid=i_icon_id permvalue=195147736 permskip=0 permnegated=0|permsid=b_client_is_sticky permvalue=1 permskip=0 permnegated=0 permgrant=100|permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0|permsid=b_client_skip_channelgroup_permissions permvalue=0 permskip=0 permnegated=0|permsid=b_channel_create_semi_permanent permvalue=0 permskip=0 permnegated=0|permsid=b_channel_create_permanent permvalue=0 permskip=0 permnegated=0|permsid=b_channel_create_temporary permvalue=0 permskip=0 permnegated=0');
            }
            elsif ($botname eq
                    $bot_names[2] && $settings_ref->{'OS_Detection_On'} ne 0) {
                my $Icon = 308531738;
                $win_group = $group_id;
                $groups_ref->{'Group_Windows'} = $group_id;
                &$sub_send( 'servergroupaddperm sgid='.$win_group.
                    ' permsid=i_icon_id permvalue='.$Icon
                    .' permskip=0 permnegated=0|permsid=i_client_max_channel_subscriptions permvalue=-1 permskip=0 permnegated=0|permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0');
            }
            elsif ($botname eq
                    $bot_names[3] && $settings_ref->{'OS_Detection_On'} ne 0) {
                my $Icon = 748058496;
                $lin_group = $group_id;
                $groups_ref->{'Group_Linux'} = $group_id;
                &$sub_send( 'servergroupaddperm sgid='.$lin_group.
                    ' permsid=i_icon_id permvalue='.$Icon
                    .' permskip=0 permnegated=0|permsid=i_client_max_channel_subscriptions permvalue=-1 permskip=0 permnegated=0|permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0');
            }
            elsif ($botname eq
                    $bot_names[4] && $settings_ref->{'OS_Detection_On'} ne 0) {
                my $Icon = 214523874;
                $mac_group = $group_id;
                $groups_ref->{'Group_Mac'} = $group_id;
                &$sub_send( 'servergroupaddperm sgid='.$mac_group.
                    ' permsid=i_icon_id permvalue='.$Icon
                    .' permskip=0 permnegated=0|permsid=i_client_max_channel_subscriptions permvalue=-1 permskip=0 permnegated=0|permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0');
            }
            elsif ($botname eq
                    $bot_names[5] && $settings_ref->{'OS_Detection_On'} ne 0) {
                my $Icon = 124010262;
                $ios_group = $group_id;
                $groups_ref->{'Group_iOS'} = $group_id;
                &$sub_send( 'servergroupaddperm sgid='.$ios_group.
                    ' permsid=i_icon_id permvalue='.$Icon
                    .' permskip=0 permnegated=0|permsid=i_client_max_channel_subscriptions permvalue=-1 permskip=0 permnegated=0|permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0');
            }
            elsif ($botname eq
                    $bot_names[6] && $settings_ref->{'OS_Detection_On'} ne 0) {
                my $Icon = 190834930;
                $android_group = $group_id;
                $groups_ref->{'Group_Android'} = $group_id;
                &$sub_send( 'servergroupaddperm sgid='.$android_group.
                    ' permsid=i_icon_id permvalue='.$Icon
                    .' permskip=0 permnegated=0|permsid=i_client_max_channel_subscriptions permvalue=-1 permskip=0 permnegated=0|permsid=b_group_is_permanent permvalue=0 permskip=0 permnegated=0');
            }
            if ($group_id and
                    $settings_ref->{'OS_Detection_Sort_Order'} !~ /Default/oi) {
                &$sub_send( 'servergroupaddperm sgid='.$group_id
                    .' permsid=i_group_sort_id permvalue='
                    .$settings_ref->{'OS_Detection_Sort_Order'}
                    .' permskip=0 permnegated=0' );
            }
            $botname =~ s/\\s/ /go;
            &$sub_log("SET  \t- Group Creator     \t- Created temporary GroupID: "
                .$group_id.' - '.$botname, 1) if $group_id;
            sleep 0.1;
            next;
        }
    }
}

# Cleanup All RbMod Groups
sub Rbm_CleanGroups {
    my $Shutdown = shift;
    my $Override = shift;
    my ($tik,$tik2,$cnt,$GuestName,$groupID,$groupName,$Client) = (0,0,0);
    unless ($Override) {
        my $oldgroups_ref = &$sub_query('servergrouplist', 'namemode.*?error id=0 msg=ok');
        unless (defined $QuiteBoot) {
            &$sub_send('sendtextmessage targetmode=3 target=1 msg=[COLOR=BLUE][B]Removing\sDormant\sGroups...[/B][/COLOR]');
        }
        unless ($oldgroups_ref) {
            &$sub_log("ERROR \t- TS3 Query          \t- Couldn't query the servergrouplist!" );
            $oldgroups_ref = &$sub_query('servergrouplist', 'namemode.*?error id=0 msg=ok');
            return unless $oldgroups_ref;
        }
        &$sub_log("LOAD  \t- Group Cleaner     \t- Launching dormant RbMod group cleaner...", 1);
        my @oldgroups = split(/\|/o,$$oldgroups_ref);
        if ( $settings_ref->{'Guest_Group_Name'} !~ /default/io ) {
            ($GuestName) = &$sub_cleantext($settings_ref->{'Guest_Group_Name'});
            $$GuestName =~ s/\\s\S+$//go;
            $GuestName = $$GuestName;
        }
        for (@oldgroups) {
            $_ =~ s/[^!-~\s]//go;
            $groupID = undef;
            if ($settings_ref->{'Guest_Group_Name'} !~ /default/io) {
                ($groupID) = $_ =~ /sgid=(\d+) name\=$GuestName /i;
            }
            ($groupID,$groupName) = $_ =~ /sgid=(\d+) name\=($GuestName|Windows|Mac|OS\\sX|Linux|iOS|Android|Sticky|Temperature\\sUnavailable|Internal\\sConnection|\\s\S+\\s|Ping\\s\d+ms|Status\\s\d+|\S+\\s\d+|\-?\d+C\\s\-?\d+F|\d+\\sHop[s]?|\"\S+\") /oi;
            ++$cnt if defined $groupID;
        }
        my $convert = $cnt;
        my $newconvert = &Rbm_ReadSeconds(($convert / 4));
        if ($newconvert) {
            &$sub_log("INFO  \t- Group Cleaner     \t- Attempting to cleanup ".$convert.' old RbM groups...', 1);
            &$sub_log("INFO  \t- Group Cleaner     \t- Estimated Time Remaining: ".$$newconvert.'...', 1);
        }
        for (sort @oldgroups) {
            $_ =~ s/[^!-~\s]//go;
            ($groupID,$groupName) = undef;
            ($groupID,$groupName) = $_ =~ /sgid=(\d+) name\=($GuestName|Windows|Mac|OS\\sX|Linux|iOS|Android|Sticky|Temperature\\sUnavailable|Internal\\sConnection|\\s\S+\\s|Ping\\s\d+ms|Status\\s\d+|\S+\\s\d+|\S+\\s\\s\d+|\-?\d+C\\s\-?\d+F|\d+\\sHop[s]?|\"\S+\") /oi            if $GuestName;
            if ($groupID && $groupID > 5) {
                $groupName =~ s/\\s/ /go;
                &$sub_log("OK  \t- Group Cleaner     \t- Removed GroupID: ".$groupID.' - '.$groupName, 1);
                &$sub_send('servergroupdel sgid='.$groupID.' force=1');
                sleep 0.04;
                $tik++;
                if ($tik >= 20) {
                    sleep 0.75;
                    $tik = 0;
                }
                $tik2++;
            }
        }
        &$sub_log("OK  \t- Group Cleaner     \t- Finished cleaning ".$tik2.' dormant RbMod groups.', 1);
    }
    if ($Shutdown && ($settings_ref->{'Traffic_Meter_On'} eq 1 or defined $Override)) {
        my $FFClients_ref = \%FFClients;
        my $online_ref = \%online;
        my ($CLID,$DBID);
        &Rbm_ParentCaching('Traffic_Meter_On',undef,'Settings');
        foreach $CLID (keys %$online_ref) {
            &$sub_send('clientdelperm cldbid='.$online_ref->{$CLID}{'DBID'}.' permsid=i_icon_id');
            sleep 0.2;
        }
#        foreach $DBID (keys %$FFClients_ref) {
#            $DBID = $FFClients_ref->{$DBID}{'DBID'};
#            &$sub_send('clientdelperm cldbid='.$DBID.' permsid=i_icon_id');
#            sleep 0.05;
#        }
        &$sub_log("DONE  \t- Group Cleaner     \t- Cleaned RbMod Groups and online client icon slots...", 1);
    }
}

# Connect main RbMod socket to TS3 server
sub Rbm_Socket {
    my ($settings_ref,$name,$query_login,$query_address,$query_pass,$query_port,
            $virt_port) = @_;
    my ($CountAttempt,$response) = 1;
    &$sub_log("LOAD \t- Socket            \t- Connecting to Query Socket...", 1);
    $SIG{PIPE} = 'IGNORE';
    foreach(1..$settings_ref->{'Query_Connect_Retry'}) {
       ($response) = &Rbm_CallServer($name, $query_address, $query_login,
               $query_pass, $query_port, $virt_port);
       if ( $response ) {
           my $Name_ref = &$sub_cleantext($name, 1);
           &$sub_log("OK    \t- Socket         \t- ".$$Name_ref.' Socket Connected Successfully to '.$sock->peerhost.' ('.$sock->peerport.')', 1);
           last;
       }
       &$sub_log("INFO \t- Socket        \t- Attempt \(".$CountAttempt.'/'.$settings_ref->{'Query_Connect_Retry'}.') Retrying Socket again in '
               .$settings_ref->{'Query_Connect_Retry_Delay'}.' seconds.', 1);
       sleep( $settings_ref->{'Query_Connect_Retry_Delay'} );
       ++$CountAttempt;
    }
    $sock->autoflush(1);
    $sockselect = new IO::Select($sock);
    &$sub_send( 'login '.$query_login.' '.$query_pass );
    &$sub_send( 'use port='.$virt_port );
    if ( length($name) < 3 ) {
        &$sub_log("WARN\t- Socket          \t- Query name ".$name.' too short!', 1);
        &$sub_log("WARN\t- Socket          \t- Padding ".$name.'!', 1);
        $name .= 'Bot';
    }
    my $clientname_ref  = &$sub_query('clientupdate client_nickname='.$name);
    unless (defined $QuiteBoot) {
        &$sub_send('sendtextmessage targetmode=3 target=1 msg=[COLOR=NAVY][B]\\p_)\s\s\\p_\s\s\\p\\\/\\p\s_\s\s\s_\\p[/B][/COLOR]');
        &$sub_send('sendtextmessage targetmode=3 target=1 msg=[COLOR=NAVY][B]\\p\s\s\s\\\\\s\\p_)\\p\s\s\s\s\\p\(_\)\(_\]\s[/COLOR][COLOR=BLUE]Started.[/B][/COLOR]');
    }
    sleep 0.2;
    if ( $clientname_ref && $$clientname_ref =~ m/id\=513/o ) {
        &$sub_log("WARN\t- Socket          \t- Unable to grab ".$name.' query name.', 1);
        &$sub_log("INFO\t- Socket          \t- Attempting to use ".$name.' 2 as a query name...', 1);
        &$sub_send('clientupdate client_nickname='.$name.'\s2');
    }
    &$sub_send( 'servernotifyregister event=server' );
    &$sub_send( 'servernotifyregister event=textserver' );
    &$sub_send( 'servernotifyregister event=textprivate' );
}

# Connect main RbMod socket to TS3 server
sub Rbm_CallServer {
    my ($name,$query_address,$query_login,$query_pass,$query_port,$virt_port) = @_;
    $sock = undef;
    my $answer;
    $|    = 1;
    for (0..1) {
        return 1 if $sock && $sock->connected;
        $sock = IO::Socket::INET->new(
            PeerAddr  => $query_address,
            PeerPort  => $query_port,
            Proto     => 'TCP',
            Keepalive => 1,
            Timeout   => 5,
            Blocking  => 0,
        ) or &$sub_log("WARN \t- Socket          \t- TCP socket failed to start: ".$!, 1) && last;
    }
    &$sub_log("INFO \t- Socket         \t- Waiting to try again...", 1);
    return undef;
}

sub Rbm_CheckGuestExemptions {
    my $CLID = shift;
    my $bytes_ref = &$sub_query('clientinfo clid='.$CLID,
        'connection_client_ip.*?error id=0 msg=ok');
    unless ($bytes_ref) {
        sleep 0.3;
        $bytes_ref = &$sub_query('clientinfo clid='.$CLID,
            'connection_client_ip.*?error id=0 msg=ok');
    }
    return unless $bytes_ref;
    my ($DBID,$search,$joined,$exempt) = $online{$CLID}{'DBID'};
    my ($ServerGroups) = $$bytes_ref =~ /servergroups=(\S+) client_created/o;
    if (exists $FFClients{$DBID}{'UserGroups'}) {
        $ServerGroups = $ServerGroups.','.$FFClients{$DBID}{'UserGroups'};
    }
    else {
        $ServerGroups = $ServerGroups;
    }
    my @GroupsJoined = split /\,/,$ServerGroups;
    my @GroupsExempt = split /\,/,$settings_ref->{'Guest_Group_Exempt_Group_IDs'};
    foreach $joined (@GroupsJoined) {
        foreach $exempt (@GroupsExempt) {
            if ( $joined == $exempt ) {
                return 1;
            }
        }
    }
}

sub Rbm_CheckExemptions {
    my ($CLID,$Setting2Check) = @_;
    my $online_ref = \%online;
    return undef unless $Setting2Check;
    return undef unless $online_ref->{$CLID}{'UserGroups'};
    my @CurrentGroups = split(/\,/, $online_ref->{$CLID}{'UserGroups'} );
    my @ExemptGroups = split(/\,/, $Setting2Check );
    my ($GroupID,$Exempt);
    foreach $GroupID (@CurrentGroups) {
        foreach $Exempt (@ExemptGroups) {
            if ( $Exempt == $GroupID ) {
                return 1;
            }
        }
    }
}

sub Rbm_check_admin_status {
    my ($invokerid,$settings_ref,$variable) = @_;
    my $SET_TriggersAdmins = $settings_ref->{$variable};
    my $bytes_ref = &$sub_query('clientinfo clid='.$invokerid,
            'connection_client_ip.*?error id=0 msg=ok');
    return undef unless $bytes_ref;
    my ($Idletime,$version,$os,$DBID,$UserGroups) = $$bytes_ref
            =~ /client_idle_time=(\d+) .*?version=(\S+) client_platform=(\S+) .*?client_database_id=(\d+) .*?servergroups=(\S+)/oi;
    return unless $UserGroups;
    my @JoinedGroupIDs = split /\,/, $UserGroups;
    my @AcceptedGroupIDs = split /\,/, $SET_TriggersAdmins;
    my ($ID,$JoinedID);
    foreach $ID (@AcceptedGroupIDs) {
        foreach $JoinedID (@JoinedGroupIDs) {
            if ($ID == $JoinedID) {
                return 1;
            }
        }
    }
}

sub Rbm_ChannelDeleteLoadFF {
    my $rooms_ref = shift;
    unless (-e 'rbm_stored/rbm_channels.cf') {
        open(my $TMP, ">".'rbm_stored/rbm_channels.cf') or die $!;
        close $TMP;
    }
    open my $FF, "+<",'rbm_stored/rbm_channels.cf'
            or die 'Can\'t load rbm_channels.cf! '.$!;
    flock($FF, 2);
    $FF =~ s/\s+$//;
    my ($channels) = <$FF>;
    my $length = 0;
    $length = length($channels) if $channels;
    $rooms_ref->{'Length'}{'Length'} = $length;
    my ($LiveRoom,$channelstr,$ChanID,$ChanUsed,$ChanUsedBy,@split);
#   Load in LIVE channels
    $channellist_ref = &$sub_query('channellist','pid=\d+ channel_order=\d+.*?error id=0 msg=ok');
    unless ( $channellist_ref ) {
       &$sub_log("ERROR \t- TS3 Query         \t- Couldn't query the channellist!");
        return;
    }
    my (@LiveRooms) = $$channellist_ref =~ /cid=(\d+)/gc;
    foreach $LiveRoom (@LiveRooms) {
        my ($ChanName) = $$channellist_ref =~ /cid\=$LiveRoom pid=\d+ channel_order=\d+ channel_name=(\S+) /;
        $rooms_ref->{$LiveRoom}{'TimeUsed'} = time;
#        $rooms_ref->{$LiveRoom}{'UsedBy'} = '';
        $rooms_ref->{$LiveRoom}{'Name'} = $ChanName;
    }
    &$sub_log("LOAD \t- Database        \t- Finished loading Live channel list into memory. ".scalar(@LiveRooms).' channels.', 1)
            if @LiveRooms;
#   Load in Flat File Channels
    if ($channels) {
        @split = split(/\|/,$channels);
        foreach $channelstr (@split) {
            ($ChanID,$ChanUsed,$ChanUsedBy) = $channelstr =~ /ChID=(\d+) ChUsed=(\d+) ChUsedBy=(\S+)/;
            $rooms_ref->{$ChanID}{'TimeUsed'} = $ChanUsed if defined $ChanUsed;
            $rooms_ref->{$ChanID}{'UsedBy'} = $ChanUsedBy if defined $ChanUsedBy;
        }
        &$sub_log("LOAD \t- Database        \t- Finished loading DB channel list into memory. ".scalar(@split).' channel rows found.', 1);
        @split = ();
    }
    return $FF;
}

sub Rbm_ClientInfoLoadFF {
    my $reload = shift;
    %FFClients = () if defined $reload;
    my $FFClients_ref = \%FFClients;
    unless (-e 'rbm_stored/rbm_clients.cf') {
        open(my $TMP, ">".'rbm_stored/rbm_clients.cf') or die $!;
        close $TMP;
    }
    open $FFCLList, "+<",'rbm_stored/rbm_clients.cf'
        or die 'Can\'t load rbm_clients.cf! '.$!;
    flock($FFCLList, 2);
    $FFCLList =~ s/\s+$//;
    my ($clients) = <$FFCLList>;
    my $length = length($clients // 0);
    my $clientstr;
    $FFClients_ref->{'Length'}{'Length'} = $length;
    if ( $clients ) {
        my ($clDBID,$CLIP,$DNS,$CLNick,$CLHops,$CLHopsRead,$CLTotalTime,$Recv,
            $CLastChan,$CLastOnline,$UserGroups,$Punished,$Send,$RBL,$Pingable,
            $Pingable2,$Pingable3,$TagLine,$Flood2,$Flood3,$Flood4,
            $Flood5,$Flood6,$CCode);
        my @split = split(/\|/,$clients);
        foreach $clientstr (@split) {
            ($clDBID,$CLIP,$DNS,$CLNick,$CLHops,$CLHopsRead,$CLTotalTime,$Recv,
                    $CLastChan,$CLastOnline,$UserGroups,$Punished,$Send,$RBL,
                    $Pingable,$Pingable2,$Pingable3,$TagLine,
                    $Flood2,$Flood3,$Flood4,$Flood5,$Flood6,$CCode) = undef;
            ($clDBID)      = $clientstr =~ /DB\=(\d+)/;
            next unless $clDBID;
            ($CLNick)      = $clientstr =~ /NIK=(\S+)\|?/so;
            ($CLIP)        = $clientstr =~ /IP=(\S+)\|?/so;
            ($DNS)         = $clientstr =~ /DNS=(\S+)\|?/so;
            ($CLHops)      = $clientstr =~ /HPS=(\d+)\|?/so;
            ($CLHopsRead)  = $clientstr =~ /HPR=(\d+)\|?/so;
            ($CLTotalTime) = $clientstr =~ /TTO=(\d+)\|?/so;
            ($CLastOnline) = $clientstr =~ /LO=(\d+)\|?/so;
            ($CLastChan)   = $clientstr =~ /LCH=(\d+)\|?/so;
            ($Flood2)      = $clientstr =~ /JFL2=(\S+)\|?/so;
            ($Flood3)      = $clientstr =~ /JFL3=(\S+)\|?/so;
            ($Flood4)      = $clientstr =~ /JFL4=(\S+)\|?/so;
            ($Flood5)      = $clientstr =~ /JFL5=(\S+)\|?/so;
            ($Flood6)      = $clientstr =~ /JFL6=(\S+)\|?/so;
            ($UserGroups)  = $clientstr =~ /GPS=(\S+)\|?/so;
            ($Punished)    = $clientstr =~ /PUN=(\d+)\|?/so;
            ($Send)        = $clientstr =~ /TX=(\d+)\|?/so;
            ($Recv)        = $clientstr =~ /RX=(\d+)\|?/so;
            ($RBL)         = $clientstr =~ /RBL=(\d+)\|?/so;
            ($Pingable)    = $clientstr =~ /PNG=(\S+)\|?/so;
            ($Pingable2)   = $clientstr =~ /PNG2=(\S+)\|?/so;
            ($Pingable3)   = $clientstr =~ /PNG3=(\S+)\|?/so;
            ($TagLine)     = $clientstr =~ /TAG=(\S+)\|?/so;
            ($CCode)       = $clientstr =~ /CC=(\S+)\|?/so;
            $FFClients_ref->{$clDBID}{'DBID'}         = $clDBID;
            $FFClients_ref->{$clDBID}{'CCode'}        = $CCode       if defined $CCode;
            $FFClients_ref->{$clDBID}{'IP'}           = $CLIP        if defined $CLIP;
            $FFClients_ref->{$clDBID}{'DNS'}          = $DNS         if defined $DNS;
            $FFClients_ref->{$clDBID}{'Nickname'}     = $CLNick      if defined $CLNick;
            $FFClients_ref->{$clDBID}{'Hops'}         = $CLHops      if defined $CLHops;
            $FFClients_ref->{$clDBID}{'HopsRead'}     = $CLHopsRead  if defined $CLHopsRead;
            $FFClients_ref->{$clDBID}{'CLTotalTime'}  = $CLTotalTime if defined $CLTotalTime;
            $FFClients_ref->{$clDBID}{'LastChannel'}  = $CLastChan   if defined $CLastChan;
            $FFClients_ref->{$clDBID}{'LastOnline'}   = $CLastOnline if defined $CLastOnline;
            $FFClients_ref->{$clDBID}{'JoinFlood2'}   = $Flood2      if defined $Flood2;
            $FFClients_ref->{$clDBID}{'JoinFlood3'}   = $Flood3      if defined $Flood3;
            $FFClients_ref->{$clDBID}{'JoinFlood4'}   = $Flood4      if defined $Flood4;
            $FFClients_ref->{$clDBID}{'JoinFlood5'}   = $Flood5      if defined $Flood5;
            $FFClients_ref->{$clDBID}{'JoinFlood6'}   = $Flood6      if defined $Flood6;
            $FFClients_ref->{$clDBID}{'UserGroups'}   = $UserGroups  if defined $UserGroups;
            $FFClients_ref->{$clDBID}{'ChanPunished'} = $Punished    if defined $Punished;
            $FFClients_ref->{$clDBID}{'TotalTx'}      = $Send        if defined $Send;
            $FFClients_ref->{$clDBID}{'TotalRx'}      = $Recv        if defined $Recv;
            $FFClients_ref->{$clDBID}{'RBLRead'}      = $RBL         if defined $RBL;
            $FFClients_ref->{$clDBID}{'Pingable'}     = $Pingable    if defined $Pingable;
            $FFClients_ref->{$clDBID}{'Pingable2'}    = $Pingable2   if defined $Pingable2;
            $FFClients_ref->{$clDBID}{'Pingable3'}    = $Pingable3   if defined $Pingable3;
            $FFClients_ref->{$clDBID}{'TagLine'}      = $TagLine     if defined $TagLine;
        }
        my $size = keys %$FFClients_ref;
        &$sub_log("LOAD \t- Database        \t- Finished loading client database into memory. ".$size.' total clients stored.', 1);
    }
}

sub Rbm_ClientInfoReadFF {
    my $CheckCLID = shift;
    my $FFClients_ref = \%FFClients;
    my $online_ref = \%online;
    my $dbid = $online_ref->{$CheckCLID}{'DBID'};
    $online_ref->{$CheckCLID}{'CLTotalTime'}  = $FFClients_ref->{$dbid}{'CLTotalTime'}
            if $FFClients_ref->{$dbid}{'CLTotalTime'};
    $online_ref->{$CheckCLID}{'LastChannel'}  = $FFClients_ref->{$dbid}{'LastChannel'}
            if $FFClients_ref->{$dbid}{'LastChannel'};
    $online_ref->{$CheckCLID}{'LastOnline'}   = $FFClients_ref->{$dbid}{'LastOnline'}
            if $FFClients_ref->{$dbid}{'LastOnline'};
    $online_ref->{$CheckCLID}{'UserGroups'}   = $FFClients_ref->{$dbid}{'UserGroups'}
            if $FFClients_ref->{$dbid}{'UserGroups'};
    $online_ref->{$CheckCLID}{'ChanPunished'} = $FFClients_ref->{$dbid}{'ChanPunished'}
            if $FFClients_ref->{$dbid}{'ChanPunished'};
    $online_ref->{$CheckCLID}{'Hops'}         = $FFClients_ref->{$dbid}{'Hops'}
            if $FFClients_ref->{$dbid}{'Hops'};
    $online_ref->{$CheckCLID}{'HopsRead'}     = $FFClients_ref->{$dbid}{'HopsRead'}
            if $FFClients_ref->{$dbid}{'HopsRead'};
    $online_ref->{$CheckCLID}{'Pingable'}     = $FFClients_ref->{$dbid}{'Pingable'}
            if $FFClients_ref->{$dbid}{'Pingable'};
    $online_ref->{$CheckCLID}{'Pingable2'}     = $FFClients_ref->{$dbid}{'Pingable2'}
            if $FFClients_ref->{$dbid}{'Pingable2'};
    $online_ref->{$CheckCLID}{'Pingable3'}     = $FFClients_ref->{$dbid}{'Pingable3'}
            if $FFClients_ref->{$dbid}{'Pingable3'};
    $online_ref->{$CheckCLID}{'TagLine'}      = $FFClients_ref->{$dbid}{'TagLine'}
            if $FFClients_ref->{$dbid}{'TagLine'};
    $online_ref->{$CheckCLID}{'DNS'}          = $FFClients_ref->{$dbid}{'DNS'}
            if $FFClients_ref->{$dbid}{'DNS'};
#    $online_ref->{$CheckCLID}{'CCode'}        = $FFClients_ref->{$dbid}{'CCode'}
#            if $FFClients_ref->{$dbid}{'CCode'};
    $online_ref->{$CheckCLID}{'JoinFlood2'}   = $FFClients_ref->{$dbid}{'JoinFlood2'}
            if $FFClients_ref->{$dbid}{'JoinFlood2'};
    $online_ref->{$CheckCLID}{'JoinFlood3'}   = $FFClients_ref->{$dbid}{'JoinFlood3'}
            if $FFClients_ref->{$dbid}{'JoinFlood3'};
    $online_ref->{$CheckCLID}{'JoinFlood4'}   = $FFClients_ref->{$dbid}{'JoinFlood4'}
            if $FFClients_ref->{$dbid}{'JoinFlood4'};
    $online_ref->{$CheckCLID}{'JoinFlood5'}   = $FFClients_ref->{$dbid}{'JoinFlood5'}
            if $FFClients_ref->{$dbid}{'JoinFlood5'};
    $online_ref->{$CheckCLID}{'JoinFlood6'}   = $FFClients_ref->{$dbid}{'JoinFlood6'}
            if $FFClients_ref->{$dbid}{'JoinFlood6'};
    if ( defined $online_ref->{$CheckCLID}{'ChanPunished'} ) {
        $online_ref->{$CheckCLID}{'ChanFloodOld'} = 1;
    }
}

sub Rbm_ClientInfoWriteFF {
    my $CheckCLID = shift;
    return unless $FFCLList;
    my ($CLIP,$DNS,$CLNick,$CLHops,$CLHopsRead,$CLTotalTime,$CLastChan,
            $CLastOnline,$UserGroups,$Punished,$Tx,$Rx,$RBL,$Pingable,$Pingable2,
            $Pingable3,$TagLine,@Tmp,$TTOL,$tag,$join,$clDBID,
            $Flood2,$Flood3,$Flood4,$Flood5,$Flood6,@DeleteOLD,$CLoffline,$CCode);
    my ($write,$FFClients_ref,$online_ref) = ('',\%FFClients,\%online);
    if ($CheckCLID && $CheckCLID =~ /^\d+$/) {
        $clDBID = $online_ref->{$CheckCLID}{'DBID'};
        $FFClients_ref->{$clDBID}{'CCode'}        = $online_ref->{$CheckCLID}{'CCode'} if exists $online_ref->{$CheckCLID}{'CCode'};
        $FFClients_ref->{$clDBID}{'DBID'}         = $online_ref->{$CheckCLID}{'DBID'};
        $FFClients_ref->{$clDBID}{'IP'}           = $online_ref->{$CheckCLID}{'IP'};
        $FFClients_ref->{$clDBID}{'DNS'}          = $online_ref->{$CheckCLID}{'DNS'};
        $FFClients_ref->{$clDBID}{'UserGroups'}   = $online_ref->{$CheckCLID}{'UserGroups'};
        $FFClients_ref->{$clDBID}{'Nickname'}     = $online_ref->{$CheckCLID}{'Nickname'};
        $FFClients_ref->{$clDBID}{'LastChannel'}  = $online_ref->{$CheckCLID}{'Channel'};
        $FFClients_ref->{$clDBID}{'LastOnline'}   = $online_ref->{$CheckCLID}{'LastOnline'};
        $FFClients_ref->{$clDBID}{'ChanPunished'} = $online_ref->{$CheckCLID}{'ChanPunished'};
        $FFClients_ref->{$clDBID}{'Pingable'}     = $online_ref->{$CheckCLID}{'Pingable'};
        $FFClients_ref->{$clDBID}{'Pingable2'}    = $online_ref->{$CheckCLID}{'Pingable2'};
        $FFClients_ref->{$clDBID}{'Pingable3'}    = $online_ref->{$CheckCLID}{'Pingable3'};
        $FFClients_ref->{$clDBID}{'TagLine'}      = $online_ref->{$CheckCLID}{'TagLine'};
        $FFClients_ref->{$clDBID}{'JoinFlood2'}   = $online_ref->{$CheckCLID}{'JoinFlood2'};
        $FFClients_ref->{$clDBID}{'JoinFlood3'}   = $online_ref->{$CheckCLID}{'JoinFlood3'};
        $FFClients_ref->{$clDBID}{'JoinFlood4'}   = $online_ref->{$CheckCLID}{'JoinFlood4'};
        $FFClients_ref->{$clDBID}{'JoinFlood5'}   = $online_ref->{$CheckCLID}{'JoinFlood5'};
        $FFClients_ref->{$clDBID}{'JoinFlood6'}   = $online_ref->{$CheckCLID}{'JoinFlood6'};
        $FFClients_ref->{$clDBID}{'CLTotalTime'}  = ($online_ref->{$CheckCLID}{'CLTotalTime'} || 0);
        $FFClients_ref->{$clDBID}{'TotalTx'}      = ( $FFClients_ref->{$clDBID}{'TotalTx'} || 0 )
                + ($online_ref->{$CheckCLID}{'Tx'} || 0);
        $FFClients_ref->{$clDBID}{'TotalRx'}      = ( $FFClients_ref->{$clDBID}{'TotalRx'} || 0 )
                + ($online_ref->{$CheckCLID}{'Rx'} || 0);
        if ( $CheckCLID && $online_ref->{$CheckCLID}{'DBID'} &&
            $online_ref->{$CheckCLID}{'DBID'} == $clDBID ) {
            $FFClients_ref->{$clDBID}{'CLTotalTime'}
                = ( $online_ref->{$CheckCLID}{'CLTotalTime'} || 0 )
                + sprintf "%.0f",($online_ref->{$CheckCLID}{'SessionTime'} / 1000);
            $TTOL = $FFClients_ref->{$clDBID}{'CLTotalTime'};
        }
    }
    else {
        my $SaveCLID;
        foreach $SaveCLID (keys %$online_ref) {
            $clDBID = $online_ref->{$SaveCLID}{'DBID'};
            next unless $clDBID;
            $FFClients_ref->{$clDBID}{'CCode'}        = $online_ref->{$SaveCLID}{'CCode'} if exists $online_ref->{$SaveCLID}{'CCode'};
            $FFClients_ref->{$clDBID}{'DBID'}         = $online_ref->{$SaveCLID}{'DBID'};
            $FFClients_ref->{$clDBID}{'IP'}           = $online_ref->{$SaveCLID}{'IP'};
            $FFClients_ref->{$clDBID}{'DNS'}          = $online_ref->{$SaveCLID}{'DNS'};
            $FFClients_ref->{$clDBID}{'UserGroups'}   = $online_ref->{$SaveCLID}{'UserGroups'};
            $FFClients_ref->{$clDBID}{'Nickname'}     = $online_ref->{$SaveCLID}{'Nickname'};
            $FFClients_ref->{$clDBID}{'LastChannel'}  = $online_ref->{$SaveCLID}{'Channel'};
            $FFClients_ref->{$clDBID}{'LastOnline'}   = $online_ref->{$SaveCLID}{'LastOnline'};
            $FFClients_ref->{$clDBID}{'ChanPunished'} = $online_ref->{$SaveCLID}{'ChanPunished'};
            $FFClients_ref->{$clDBID}{'Pingable'}     = $online_ref->{$SaveCLID}{'Pingable'};
            $FFClients_ref->{$clDBID}{'Pingable2'}    = $online_ref->{$SaveCLID}{'Pingable2'};
            $FFClients_ref->{$clDBID}{'Pingable3'}    = $online_ref->{$SaveCLID}{'Pingable3'};
            $FFClients_ref->{$clDBID}{'TagLine'}      = $online_ref->{$SaveCLID}{'TagLine'};
            $FFClients_ref->{$clDBID}{'CLTotalTime'}  = ($online_ref->{$SaveCLID}{'CLTotalTime'} || 0);
            $FFClients_ref->{$clDBID}{'TotalTx'}      = ( $FFClients_ref->{$clDBID}{'TotalTx'} || 0 )
                    + ($online_ref->{$SaveCLID}{'Tx'} || 0);
            $FFClients_ref->{$clDBID}{'TotalRx'}      = ( $FFClients_ref->{$clDBID}{'TotalRx'} || 0 )
                    + ($online_ref->{$SaveCLID}{'Rx'} || 0);
        }
    }
    foreach $CLoffline ( keys %$FFClients_ref ) {
#        next if $CLoffline eq 'Length';
        ($CLIP,$DNS,$CLNick,$CLHops,$CLHopsRead,$CLTotalTime,$CLastChan,
            $CLastOnline,$UserGroups,$Punished,$Tx,$Rx,$RBL,$Pingable,
            $Pingable2,$Pingable3,$TagLine,@Tmp,$tag,$join,$clDBID,
            $Flood2,$Flood3,$Flood4,$Flood5,$Flood6,$CCode) = undef;
        @Tmp = ();
        $clDBID = $FFClients_ref->{$CLoffline}{'DBID'};
        $CLNick = $FFClients_ref->{$CLoffline}{'Nickname'};
        $CLastOnline = $FFClients_ref->{$CLoffline}{'LastOnline'};
        next if !$CLNick or $CLNick eq 'Length';
#       Remove stagnant DB entries older than cache time
        if ($CLastOnline && $CLNick && $clDBID && $CheckCLID && $CheckCLID =~ /^\d+$/) {
            unless ( ($CLastOnline + $settings_ref->{'Database_Active_Clients_Cache_Time'}) > time ) {
                my ($LastLoginElapsed) = &Rbm_ReadSeconds(time - $CLastOnline);
                &$sub_log( "INFO \t- Database          \t- Removing "
                    .$CLNick.' for laying dormant over'.$$LastLoginElapsed.'.');
                push(@DeleteOLD,$clDBID);
                next;
            }
        }
        $CCode       = $FFClients_ref->{$CLoffline}{'CCode'}
            if exists $FFClients_ref->{$CLoffline}{'CCode'};
        $CLIP        = $FFClients_ref->{$CLoffline}{'IP'};
        $DNS         = $FFClients_ref->{$CLoffline}{'DNS'};
        $CLHops      = $FFClients_ref->{$CLoffline}{'Hops'} || 1;
        $CLHopsRead  = $FFClients_ref->{$CLoffline}{'HopsRead'};
        $CLTotalTime = $FFClients_ref->{$CLoffline}{'CLTotalTime'};
        $CLastChan   = $FFClients_ref->{$CLoffline}{'LastChannel'};
        $UserGroups  = $FFClients_ref->{$CLoffline}{'UserGroups'};
        $Punished    = $FFClients_ref->{$CLoffline}{'ChanPunished'};
        $Tx          = $FFClients_ref->{$CLoffline}{'TotalTx'};
        $Rx          = $FFClients_ref->{$CLoffline}{'TotalRx'};
        $RBL         = $FFClients_ref->{$CLoffline}{'RBLRead'};
        $Pingable    = $FFClients_ref->{$CLoffline}{'Pingable'};
        $Pingable2   = $FFClients_ref->{$CLoffline}{'Pingable2'};
        $Pingable3   = $FFClients_ref->{$CLoffline}{'Pingable3'};
        $TagLine     = $FFClients_ref->{$CLoffline}{'TagLine'};
        $Flood2      = $FFClients_ref->{$CLoffline}{'JoinFlood2'} if exists $FFClients_ref->{$CLoffline}{'JoinFlood2'};
        $Flood3      = $FFClients_ref->{$CLoffline}{'JoinFlood3'} if exists $FFClients_ref->{$CLoffline}{'JoinFlood3'};
        $Flood4      = $FFClients_ref->{$CLoffline}{'JoinFlood4'} if exists $FFClients_ref->{$CLoffline}{'JoinFlood4'};
        $Flood5      = $FFClients_ref->{$CLoffline}{'JoinFlood5'} if exists $FFClients_ref->{$CLoffline}{'JoinFlood5'};
        $Flood6      = $FFClients_ref->{$CLoffline}{'JoinFlood6'} if exists $FFClients_ref->{$CLoffline}{'JoinFlood6'};
        push @Tmp, 'DB=' .$clDBID;
        push @Tmp, 'NIK='.$CLNick      if $CLNick;
        push @Tmp, 'CC=' .$CCode       if $CCode;
        push @Tmp, 'IP=' .$CLIP        if $CLIP;
        push @Tmp, 'DNS='.$DNS         if $DNS;
        push @Tmp, 'HPS='.$CLHops      if $CLHops;
        push @Tmp, 'HPR='.$CLHopsRead  if $CLHopsRead;
        push @Tmp, 'TTO='.$CLTotalTime if $CLTotalTime;
        push @Tmp, 'LO=' .$CLastOnline if $CLastOnline;
        push @Tmp, 'LCH='.$CLastChan   if $CLastChan;
        if ($settings_ref->{'OnJoin_Reconnect_Gauge_On'} ne 0
                and $FFClients_ref->{$CLoffline}{'Disconnected'} ) {
#           Join Flood Strike 1
            if ( $CLastOnline && $CLastOnline > (time - $settings_ref->{'OnJoin_Reconnect_Gauge_Requirements'}) ) {
                $FFClients_ref->{$CLoffline}{'JoinFlood2'} = time;
                push @Tmp, 'JFL2='.time;
            }
#           Join Flood Strike 2
            if ( $Flood2 && $Flood2 > (time - $settings_ref->{'OnJoin_Reconnect_Gauge_Requirements'}) ) {
                $FFClients_ref->{$CLoffline}{'JoinFlood3'} = $Flood2;
                push @Tmp, 'JFL3='.$Flood2;
            }
#           Join Flood Strike 3
            if ( $Flood3 && $Flood3 > (time - $settings_ref->{'OnJoin_Reconnect_Gauge_Requirements'}) ) {
                $FFClients_ref->{$CLoffline}{'JoinFlood4'} = $Flood3;
                push @Tmp, 'JFL4='.$Flood3;
            }
#           Join Flood Strike 4
            if ( $Flood4 && $Flood4 > (time - $settings_ref->{'OnJoin_Reconnect_Gauge_Requirements'}) ) {
                $FFClients_ref->{$CLoffline}{'JoinFlood5'} = $Flood4;
                push @Tmp, 'JFL5='.$Flood4;
            }
#           Join Flood Strike 5
            if ( $Flood5 && $Flood5 > (time - $settings_ref->{'OnJoin_Reconnect_Gauge_Requirements'}) ) {
                $FFClients_ref->{$CLoffline}{'JoinFlood6'} = $Flood5;
                push @Tmp, 'JFL6='.$Flood5;
            }
        }
        push @Tmp, 'GPS='.$UserGroups  if $UserGroups;
        push @Tmp, 'PUN='.$Punished    if $Punished;
        push @Tmp, 'TX=' .$Tx          if $Tx;
        push @Tmp, 'RX=' .$Rx          if $Rx;
        push @Tmp, 'RBL='.$RBL         if $RBL;
        push @Tmp, 'PNG='.$Pingable    if $Pingable;
        push @Tmp, 'PNG2='.$Pingable2  if $Pingable2;
        push @Tmp, 'PNG3='.$Pingable3  if $Pingable3;
        push @Tmp, 'TAG='.$TagLine     if $TagLine;
        $join  = join ' ', @Tmp;
        $write = $write.'|' if $write =~ /^\S+/;
        $write = $write.$join;
        delete $FFClients_ref->{$CLoffline}{'Disconnected'}
                if exists $FFClients_ref->{$CLoffline}{'Disconnected'};
    }
#   Remove stagnant DB entries older than cache time
    for (@DeleteOLD) {
        delete $FFClients{$_};
        Rbm_TSSend('clientdbdelete cldbid='.$_);
        sleep 0.02;
    }
    my $OldLength = $FFClients_ref->{'Length'}{'Length'} || 0;
    my $NewLength = length($write);
    if ($OldLength > $NewLength) {
        $write = sprintf("%-*s", $OldLength, $write);
    }
    else {
        $write =~ s/[\s]*$//i;
    }
    sysseek($FFCLList, 0, 0);
    syswrite $FFCLList,$write.$nl;
    $FFClients_ref->{'Length'}{'Length'} = $NewLength;
    if ( $CheckCLID && $CheckCLID =~ /^\d+$/ ) {
        my ($FirstLoginElapsed) = &Rbm_ReadSeconds($TTOL);
        &$sub_log("WRITE\t- Database         \t- Updated "
                .$online_ref->{$CheckCLID}{'Nickname'}.'\'s Time:'
                .$$FirstLoginElapsed.' ('.$TTOL.' seconds)');
    }
    else {
        &$sub_log("READ\t- Database         \t- Saved Client Database\.");
    }
}

sub Rbm_ClientInfo {
    my ($clientlist_ref,$groups_ref,$channellist_ref) = @_;
    my ($FFClients_ref,$rooms_ref,$online_ref) = (\%FFClients,\%rooms,\%online);
    if (!$clientlist_ref or !$channellist_ref) {
        &$sub_log("WARN\t- TS3 Query          \t- Couldn't query the clientlist or channellist! Looping Again!");
        return ($online_ref,$badwords_ref);
    }
    my @clients_online = split /\|/, $$clientlist_ref;
    my $SET_QueryLimit = $settings_ref->{'Query_Limit'};
    my ($Counter,$CountRead,$Idletime,$version,$os,$Recording,$UserGroups,
        $Created,$TotalConnects,$CCode,$CLRx,$CLTx,$CLSessionTime,$CLIP,
        $CLID,$ChanID,$clDBID,$clName,$punished,$bytes_ref,$afk_groupID,
        $Exempt,$Away,$AwayMsg,$description,$client,$groupID,$GroupName,$ref,
        $CLGroups,@FloodTimes,@ParsedTimes,$timestamp,$TagLine,$badword,
        $swearing,$GEOACTIVE,$City,$Region,$Country,$cels,$ip2,$ip3,$ip4,
        $Elapsed,$ChanName,$ChanIcon,$CheckChan,$DateTime,$conditions,@pairs,
        $weather_msg,$weather_msg_ext,$miles,$kms,$nmiles,$TmpCCode,
        $pingable,$pingable2,$pingable3) = (0,0);
    $SET_QueryLimit = (sprintf "%.0f",($SET_QueryLimit / 2)) + 1
        if $TotalClients <= $SET_QueryLimit;
    my $readclients = $TotalClients;
    $readclients = 50 if $readclients < 50;
    if (exists $settings_ref->{'Channel_Delete_Dormant_Requirements_triggered'}) {
        --$settings_ref->{'Channel_Delete_Dormant_Requirements_triggered'};
        if ($settings_ref->{'Channel_Delete_Dormant_Requirements_triggered'} <= 0) {
            $settings_ref->{'Channel_Delete_Dormant_Requirements'}
                = $settings_ref->{'Channel_Delete_Dormant_Requirements_saved'};
            $settings_ref->{'Channel_Delete_Dormant_Requirements_Interval'}
                = $settings_ref->{'Channel_Delete_Dormant_Requirements_Interval_saved'};
            delete $settings_ref->{'Channel_Delete_Dormant_Requirements_triggered'};
            delete $settings_ref->{'Channel_Delete_Dormant_Requirements_saved'};
            delete $settings_ref->{'Channel_Delete_Dormant_Requirements_Interval_saved'};
            &Rbm_ParentCaching('Reset');
        }
        else {
            &$sub_chdel($online_ref,$rooms_ref,$settings_ref,$FFChans,$channellist_ref);
            return ($online_ref,$badwords_ref);
        }
    }
#   Loop through each clientinfo until query_limit maxed & reset
    for ( 0..1 ) {
        foreach $client (@clients_online) {
            ($os,$Idletime,$version,$Recording,$UserGroups,
            $Created,$CCode,$CLRx,$CLTx,$CLSessionTime,$CLIP,
            $CLID,$ChanID,$clDBID,$clName,$punished,$bytes_ref,$afk_groupID,
            $Exempt,$Away,$AwayMsg,$description,$groupID,$GroupName,$ref,
            $CLGroups,@FloodTimes,@ParsedTimes,$timestamp,$TagLine,$badword,
            $swearing,$GEOACTIVE,$City,$Region,$Country,$cels,$ip2,$ip3,$ip4,
            $Elapsed,$ChanName,$ChanIcon,$CheckChan,$DateTime,$conditions,@pairs,
            $weather_msg,$weather_msg_ext,$miles,$kms,$nmiles,$TmpCCode,
            $pingable,$pingable2,$pingable3) = undef;
            ($CLID,$ChanID,$clDBID,$clName) = $client =~
                /clid=(\d+) cid=(\d+) client_database_id=(\d+) client_nickname=(\S+) client_type=0/o;
            next unless $CLID;
            if ($CountRead < $SET_QueryLimit) {
#               PROCEED ONLY IF UNDER MAX LIMIT PER SECOND
                next if ($online_ref->{$CLID}{'PollTick'} || 0) == $PollTick;
                $online_ref->{$CLID}{'PollTick'} = $PollTick;
                ++$CountRead if exists $online_ref->{$CLID}{'DBID'};
#               REPEAT CLIENTINFO
                $bytes_ref = &$sub_query('clientinfo clid='.$CLID,
                    'connection_client_ip.*?error id=0 msg=ok');
                ($Idletime,$version,$os,$Recording,$UserGroups,$Created,$TotalConnects,
                    $Away,$AwayMsg,$description,$CCode,$CLRx,$CLTx,$CLSessionTime,$CLIP)
                    = $$bytes_ref =~ /client_idle_time=(\d+) .*?version=(\S+) client_platform=(\S+) .*?client_is_recording=(\d) .*?servergroups=(\S+) client_created=(\d+) .*?totalconnections=(\d+) client_away=(\d) client_away_message([\S]*? )\S.*?client_description([\S]*? )\S.*?client_country([\S]*? )\S.*?bytes_sent_total=(\d+).*?bytes_received_total=(\d+) .*?connected_time=(\d+) connection_client_ip=(\S+)/o
                    if defined $bytes_ref;
                next unless $Idletime;
#               Check Proxy IP changes
                if (exists $online_ref->{$CLID}{'IP'}
                    and $online_ref->{$CLID}{'DBID'}
                    and ($CLIP ne $online_ref->{$CLID}{'IP'})) {
                    &$sub_rbllookup($online_ref,$settings_ref,$CLID,\%FFClients,
                        $CLIP,$clDBID) if $settings_ref->{'RBL_Check_On'} ne 0;
                    $online_ref->{$CLID}{'IP'} = $CLIP;
                }
                if ($CCode ne ' ') {
                    $CCode =~ s/\=| //go;
                    $online_ref->{$CLID}{'CCode'} = $CCode;
                }
                else {
                    $CCode = undef;
                }
                if ($settings_ref->{'Ping_Meter_On'} eq 1
                    and (($online_ref->{$CLID}{'PingTime'} || 0)
                    < (time - $settings_ref->{'Ping_Meter_Interval'}))) {
                    $online_ref->{$CLID}{'PingTime'} = time + $CountRead;
                    $ip2 = $online_ref->{$CLID}{'Pingable'} || $CLIP;
                    $ip3 = $online_ref->{$CLID}{'Pingable2'} || $CLIP;
                    $ip4 = $online_ref->{$CLID}{'Pingable3'} || $CLIP;
                    if ($OSType =~ /Win/io) {
                        system(1,$^X,"./rbm_tools/rbm_ping.pl",$clDBID,$CLID,
                            $CLIP,$OSType,$ip2,$ip3,$ip4);
                    }
                    else {
                        if (fork() == 0) {
                            exec($^X,"./rbm_tools/rbm_ping.pl",$clDBID,$CLID,
                                $CLIP,$OSType,$ip2,$ip3,$ip4);
                            exit 0;
                        }
                    }
                }
#               Description Language Check
                if ($description && $description ne ' '
                    or $AwayMsg && $AwayMsg ne ' ') {
                    $description =~ s/\=| //go;
                    $AwayMsg =~ s/\=| //go;
                    if (($online_ref->{$CLID}{'description'} || '') ne $description
                            or ($online_ref->{$CLID}{'AwayMsg'} || '') ne $AwayMsg ) {
                        $online_ref->{$CLID}{'description'} = $description
                            if ($online_ref->{$CLID}{'description'} || '') ne $description;
                        $online_ref->{$CLID}{'AwayMsg'} = $AwayMsg
                            if ($online_ref->{$CLID}{'AwayMsg'} || '') ne $AwayMsg;
#                       RbMod - Check clients exemptions
                        $Exempt = &$sub_exempt($CLID,
                            $settings_ref->{'All_Language_Filters_Exempt_Group_IDs'});
                        if (!$Exempt) {
                            if ($settings_ref->{'Client_Description_Language_Filter_On'} ne 0
                                 and $description and $description =~ /\S+/i) {
                                &$sub_log("INFO  \t- Descrip. Language \t- Checking "
                                    .$description.' against word list...');
                                $description =~ s/\\s/ /go;
                                foreach $badword (@$badwords_ref) {
                                    if ($description =~ /$badword/i) {
                                        $swearing    = 1;
                                        $description =~ s/$badword//gi;
                                    }
                                }
                                $description =~ s/ /\\s/go;
                                if ($swearing) {
                                    &$sub_send( 'clientedit clid='.$CLID
                                        .' client_description='.$description );
                                }
                            }
                            if ($settings_ref->{'Client_Away_Status_Language_Filter_On'} ne 0
                                and $AwayMsg and $AwayMsg =~ /\S+/i) {
                                &$sub_log("INFO  \t- Away Language \t- Checking "
                                    .$AwayMsg.' against word list...');
                                $AwayMsg =~ s/\\s/ /go;
                                foreach $badword (@$badwords_ref) {
                                    if ($AwayMsg =~ /\Q$badword\E/i) {
                                        $swearing = 1;
                                        $AwayMsg =~ s/$badword//gi;
                                    }
                                }
                                $AwayMsg =~ s/ /\\s/go;
                                if ($swearing) {
                                    &$sub_send( 'clientkick clid='.$CLID
                                        .' reasonid=5 reasonmsg=Away\sStatus\sLanguage\sFilter' );
                                }
                            }
                        }
                        $Exempt = undef;
                    }
                }
                if ($online_ref->{$CLID}{'Parent'}) {
                    $online_ref->{$CLID}{'TxCache'} = ($online_ref->{$CLID}{'Tx'} || 0);
                    $online_ref->{$CLID}{'RxCache'} = ($online_ref->{$CLID}{'Rx'} || 0);
                    $online_ref->{$CLID}{'Tx'} = $CLTx;
                    $online_ref->{$CLID}{'Rx'} = $CLRx;
                }
#               REPEAT Feature - Channel Floods
                if ($ChanID && ($online_ref->{$CLID}{'Channel'} || -1) != $ChanID) {
                    # Channel Last used by...?
                    if (($settings_ref->{'Channel_Info_Switching_On'} eq 1)
                        and (defined $rooms_ref->{$ChanID}{'UsedBy'}
                        && $rooms_ref->{$ChanID}{'UsedBy'} ne 'Null')
                        and $Booted) {
                        $Elapsed = &Rbm_ReadSeconds((time - $rooms_ref->{$ChanID}{'TimeUsed'}), 1);
                        $$Elapsed =~ s/^[\\s]*//go;
                        if ($Elapsed and exists $rooms_ref->{$ChanID}{'Name'}) {
                            &$sub_send('sendtextmessage targetmode=1 target='.$CLID.' msg=[B][COLOR=NAVY]Channel\s[/COLOR][COLOR=BLUE]'
                                .$rooms_ref->{$ChanID}{'Name'}.'[/COLOR][COLOR=NAVY]\slast\sused\sby\s[/COLOR][COLOR=BLUE]'
                                .$rooms_ref->{$ChanID}{'UsedBy'}.'[/COLOR][COLOR=NAVY]'.$$Elapsed.'[/COLOR][/B]');
                        }
                    }
                    $rooms_ref->{$ChanID}{'TimeUsed'} = time;
                    $rooms_ref->{$ChanID}{'UsedBy'} = $online_ref->{$CLID}{'Nickname'};
                    # Game Rooms
#                    if ($settings_ref->{'Game_Rooms_On'} eq 1) {
#                        $CheckChan = &$sub_query('channelinfo cid='.$ChanID,'channel_name=\S+.*?error id=0 msg=ok');
#                        if ($CheckChan) {
#                            ($ChanName,$ChanIcon) = $$CheckChan =~ /channel_name\=(\S+).*?channel_icon_id\=(\d+)/o;
#                        }
#                        $rooms_ref->{$ChanID}{'Name'} = $ChanName if $ChanName;
#                        $rooms_ref->{$ChanID}{'Icon'} = $ChanIcon if $ChanIcon;
#                        &rbm_features::Rbm_GamerChannels($CLID,$ChanID,
#                        $ChanName,$ChanIcon,$settings_ref,$gameicons_ref,
#                        $online_ref,$rooms_ref);
#                    }
                    &$sub_chflood($CLID,$ChanID,$online_ref,$settings_ref);
                    $online_ref->{$CLID}{'Channel'} = $ChanID;
                    $FFClients{$clDBID}{'LastChannel'} = $ChanID;
                }
#               REPEAT Feature - Channel Punishment
                if ($settings_ref->{'Channel_Punish_Detection_On'} ne 0
                    && $ChanID == $settings_ref->{'Channel_Punish_Detection_Channel_ID'}
                    && !exists $online_ref->{$CLID}{'ChanPunishment'}) {
                    &$sub_chPunish( $CLID,$ChanID,$online_ref,$settings_ref,$groups_ref);
                }
                elsif ($settings_ref->{'Channel_Punish_Detection_On'} ne 0
                    && $ChanID != $settings_ref->{'Channel_Punish_Detection_Channel_ID'}
                    && exists $online_ref->{$CLID}{'ChanPunishment'} ) {
                    &$sub_chDelPunish( $CLID,$ChanID,$online_ref,$settings_ref,$groups_ref);
                }
#               REPEAT Feature - Channel Delete Dormant Channels
                if (($rooms_ref->{$ChanID}{'TimeUsed'} || 0) < (time - 5) && $Booted) {
                    $rooms_ref->{$ChanID}{'TimeUsed'} = time;
                    $rooms_ref->{$ChanID}{'UsedBy'} = $online_ref->{$CLID}{'Nickname'};
                }
#               REPEAT Feature - Nickname Language Filter
                if (($online_ref->{$CLID}{'Nickname'} || '') ne $clName) {
#                   Check for rbm_badwords Updates.
                    $DateTime = stat($BadWordsFile)->mtime;
                    if ($DateTime ne ($settings_ref->{'BadwordsDate'} || 0)) {
                        $settings_ref->{'BadwordsDate'} = $DateTime;
                        $badwords_ref = &Rbm_LoadConfigs($BadWordsFile);
                    }
                    $punished = &rbm_features::Rbm_NickLanguage($CLID,$CLIP,$clName,
                        $online_ref,$settings_ref,\%FFClients,$badwords_ref);
                    $online_ref->{$CLID}{'Nickname'} = $clName;
                }
#               REPEAT Feature - Recording Detection
                if ($Recording == 1 && ($settings_ref->{'Recording_Detect_On'} ne 0)
                    && !$online_ref->{$CLID}{'RecordExempt'}
                    && !$online_ref->{$CLID}{'RecordChecked'}) {
                    $online_ref->{$CLID}{'RecordChecked'} = 1;
                    &$sub_record($CLID,$online_ref,$settings_ref);
                }
                elsif (($Recording == 0) && ($settings_ref->{'Recording_Detect_On'} ne 0)
                    && $online_ref->{$CLID}{'RecordChecked'}
                    && !$online_ref->{$CLID}{'RecordExempt'}) {
                    delete $online_ref->{$CLID}{'RecordChecked'};
                }
#               REPEAT Feature - AFK-Move
                if (($settings_ref->{'Automove_Client_AFK_On'} ne 0) && $Booted
                    && $online_ref->{$CLID}{'UserGroups'}) {
                    if ($settings_ref->{'Automove_Client_AFK_Channel_ID'} != $ChanID
                        && !exists $online_ref->{$CLID}{'AFKRoomID'}
                        && !exists $online_ref->{$CLID}{'ExemptFromIdleMove'}
                        && (($Idletime / 1000) > $settings_ref->{'Automove_Client_AFK_Time_Requirement'})
                        && !exists $online_ref->{$CLID}{'ChanPunished'}) {
                        &$sub_idlemove( $CLID,$ChanID,$online_ref,$settings_ref,
                            $groups_ref );
                    }
                    elsif ($settings_ref->{'Automove_Client_AFK_Return_To_Channel_On'} ne 0) {
                        if ($online_ref->{$CLID}{'BeforeAFKRoomID'}
                            && ($Idletime / 1000) < $settings_ref->{'Automove_Client_AFK_Time_Requirement'}
                            && ($online_ref->{$CLID}{'BeforeAFKRoomID'} ne $ChanID)) {
                            &$sub_send('clientmove clid='.$CLID.' cid='.$online_ref->{$CLID}{'BeforeAFKRoomID'});
                            delete $online_ref->{$CLID}{'BeforeAFKRoomID'};
                        }
                    }
                }
#               REPEAT Feature - Status
                if ($online_ref->{$CLID}{'Status'}
                    && $settings_ref->{'Status_On'} ne 0
                    && $online_ref->{$CLID}{'DBID'}) {
#                   Status idle
                    if (($online_ref->{$CLID}{'Status'} ne 'AFK'
                        && $online_ref->{$CLID}{'Status'} ne 'Idle')
                        && ($Idletime / 1000) > $settings_ref->{'Status_Idle_Time_Requirement'}) {
                        &$sub_clstatus($CLID,$ChanID,$Idletime,$online_ref,
                            $settings_ref,$groups_ref,undef,1);
                        $online_ref->{$CLID}{'Status'} = 'Idle';
                    } # Status AFK
                    elsif ($online_ref->{$CLID}{'Status'} ne 'AFK'
                        && (($Idletime / 1000) > $settings_ref->{'Status_AFK_Time_Requirement'}
                        || ($settings_ref->{'Automove_Client_AFK_On'} ne 0
                        && $ChanID == $settings_ref->{'Automove_Client_AFK_Channel_ID'})
                        || ($online_ref->{$CLID}{'Status'} ne 'AFK'
                        && $settings_ref->{'Status_AFK_Detect_TS3_Away'} ne 0 && $Away != 0))) {
                        &$sub_clstatus( $CLID,$ChanID,$Idletime,$online_ref,
                            $settings_ref,$groups_ref,undef,undef,1 );

                    } # Status Returned
                    elsif (($online_ref->{$CLID}{'Status'} ne 'Live') && $Away == 0
                        && $ChanID != $settings_ref->{'Automove_Client_AFK_Channel_ID'}
                        && (($Idletime / 1000) < $settings_ref->{'Status_Idle_Time_Requirement'})) {
                        &$sub_clstatus($CLID,$ChanID,$Idletime,$online_ref,
                            $settings_ref,$groups_ref,undef,undef,undef,1);
                    } # Remove Country information
                    if ($settings_ref->{'Status_Display_Country_OnJoin'} ne 0
                        && $online_ref->{$CLID}{'DBID'}
                        && $online_ref->{$CLID}{'Group_Status'}
                        && $CLSessionTime && $Booted
                        && $online_ref->{$CLID}{'StatusCountryName'}
                        && !$online_ref->{$CLID}{'StatusCountryNameFinished'}
                        && (($CLSessionTime / 1000)
                        >= $settings_ref->{'Status_Display_Country_OnJoin_Timeout'})) {
                        $groupID = $online_ref->{$CLID}{'Group_Status'};
                        $GroupName = $online_ref->{$CLID}{'StatusCountryName'};
                        $GroupName =~ s/\\s\-.*?$//o;
                        $GroupName =~ s/\\s/ /go;
                        $GroupName =~ s/(\, \S+)\,.*?$/$1/o if length($GroupName) > 18;
                        $GroupName =~ s/^(\S+)\, .*?$/$1/o if length($GroupName) >= 21;
                        $GroupName =~ s/ /\\s/go;
                        $GroupName = substr($GroupName,0,20).'\\s\\s('.$CLID.')';

                        &$sub_send('servergroupaddperm sgid='.$groupID
                            .' permsid=i_group_show_name_in_tree permvalue=0 permskip=0 permnegated=0');
                        &$sub_send('servergrouprename sgid='.$groupID.' name='.substr($GroupName,0,29));
                        $online_ref->{$CLID}{'StatusCountryNameFinished'} = 1;
                    } # Display weather at connect time
                    elsif ($settings_ref->{'Status_Display_Country_OnJoin'} ne 0
                        && $online_ref->{$CLID}{'DBID'}
                        && $online_ref->{$CLID}{'Group_Status'}
                        && $online_ref->{$CLID}{'Weather-Conditions'}
                        && $online_ref->{$CLID}{'Weather-Celsius'}
                        && !$online_ref->{$CLID}{'StatusCountryNameFinished'}
                        && $CLSessionTime
                        && $online_ref->{$CLID}{'StatusCountryName'}
                        && !$online_ref->{$CLID}{'StatusWeatherFinished'}
                        && (($CLSessionTime / 1000) >= ($settings_ref->{'Status_Display_Country_OnJoin_Timeout'}
                        - (sprintf "%.0f",($settings_ref->{'Status_Display_Country_OnJoin_Timeout'} / 2))))) {
                        $groupID = $online_ref->{$CLID}{'Group_Status'};
                        $conditions = $online_ref->{$CLID}{'Weather-Conditions'};
                        @pairs = grep {$_ =~ /\S/o} split /([\S]+)\\s/, $conditions;
                        $conditions = $pairs[-2].'\s'.$pairs[-1] if scalar(@pairs) > 1;
                        $conditions = $pairs[-1] if length($conditions) > 10;
                        $GroupName = $online_ref->{$CLID}{'Weather-Celsius'}.'°C\s/\s'
                            .$online_ref->{$CLID}{'Weather-Fahrenheit'}.'°F\s'
                            .$conditions;
                        if ($GroupName) {
                            $GroupName = encode("utf8", $GroupName);
                            &$sub_send('servergrouprename sgid='.$groupID.' name='.substr($GroupName,0,29));
                        }
                        $online_ref->{$CLID}{'StatusWeatherFinished'} = 1;
                    }
                }
#               REPEAT Feature - Protected Groups
                if ($Booted && $UserGroups && $online_ref->{$CLID}{'DBID'}
                    && $online_ref->{$CLID}{'UserGroups'}
                    && ($online_ref->{$CLID}{'UserGroups'} ne $UserGroups)
                    && $UserGroups =~ /\,/o) {
                    $online_ref->{$CLID}{'UserGroups'} = $UserGroups;
                    &$sub_grpprot($CLID,$online_ref,$settings_ref);
                }
#               Command Flood Monitor And Parse
                if ($online_ref->{$CLID}{'CmdFlood'}) {
                    @FloodTimes = split /\,/o, $online_ref->{$CLID}{'CmdFlood'};
                    @ParsedTimes = ();
                    foreach $timestamp (@FloodTimes) {
                        if ($timestamp && ((time - $settings_ref->{'Exclamation_Triggers_Flood_Time_Limit'}) < $timestamp)) {
                            push(@ParsedTimes,$timestamp);
                        }
                    }
                    $online_ref->{$CLID}{'CmdFlood'} = join(',',@ParsedTimes);
                    if (scalar(@ParsedTimes) >= $settings_ref->{'Exclamation_Triggers_Flood_Tolerance'}) {
                        $online_ref->{$CLID}{'CmdFloodBLOCKED'} = 1;
                    }
                    elsif ($online_ref->{$CLID}{'CmdFloodBLOCKED'}) {
                        delete $online_ref->{$CLID}{'CmdFloodBLOCKED'};
                    }
                    elsif (!$ParsedTimes[0]) {
                        delete $online_ref->{$CLID}{'CmdFlood'};
                    }
                }
                $online_ref->{$CLID}{'SessionTime'} = $CLSessionTime;
                $online_ref->{$CLID}{'UserGroups'} = $UserGroups;
            }
            # Check 2 minute reconnect spam window
            if ((($FFClients_ref->{$clDBID}{'LastOnline'} || 0) > time - 120)
                && !exists $online_ref->{$CLID}{'SkipGlobeMsgs'}) {
                $online_ref->{$CLID}{'SkipGlobeMsgs'} = 1;
            }
            if (exists $online_ref->{$CLID}{'Parent'}
                && exists $online_ref->{$CLID}{'SessionTime'}
                && (($online_ref->{$CLID}{'SessionTime'} / 1000) > 5)
                && !exists $online_ref->{$CLID}{'SkipGlobeMsgs'}
                && $Booted) {
#               Display TagLine / Description OnJoin
                if ($settings_ref->{'Verbose_Global_Onjoin_Client_Tags'} ne 0
                    and !$online_ref->{$CLID}{'TagLineSet'}) {
                    if (!exists $online_ref->{$CLID}{'TagLineCount'}) {
                        $online_ref->{$CLID}{'TagLineCount'} = time;
                    }
                    if ($online_ref->{$CLID}{'TagLineCount'} <= (time - 3)) {
                        &$sub_tagline($CLID,$online_ref,$settings_ref);
                        $online_ref->{$CLID}{'TagLineSet'} = 1;
                    }
                }
#               REPEAT Feature - Weather
                if ($settings_ref->{'Package_Weather_Underground_On'} ne 0
                    && !exists $online_ref->{$CLID}{'WeatherSet'}
                    && exists $online_ref->{$CLID}{'Weather-Celsius'}) {
                    if ($settings_ref->{'Temperatures_Global_Message'} ne 0) {
                        $weather_msg = '[B][COLOR=NAVY]'.$online_ref->{$CLID}{'Nickname'}
                            .'\'s[/COLOR][/B]';
                        $weather_msg_ext = '[B]\slocal\sweather:\s[/B][COLOR=BLUE]'
                            .$online_ref->{$CLID}{'Weather-Celsius'}.'°C\s/\s'
                            .($online_ref->{$CLID}{'Weather-Fahrenheit'} || '').'°F';
                        $weather_msg_ext = encode("utf8", $weather_msg_ext);
                        $weather_msg .= $weather_msg_ext;
                        $conditions = $online_ref->{$CLID}{'Weather-Conditions'};
                        if ($conditions and $conditions ne 'Null') {
                            $conditions =~ s/ /\\s/go;
                            $weather_msg .= '\s-\s'.$conditions;
                        }
                        $weather_msg .= '[/COLOR]';
                        &$sub_send('sendtextmessage targetmode=3 target=1 msg='.$weather_msg);
                    }
                    $online_ref->{$CLID}{'WeatherSet'} = 1;
                }
                if (!exists $online_ref->{$CLID}{'Dist_Set'} && $Booted
                    && exists $online_ref->{$CLID}{'Dist_Miles'}) {
                    $miles = $online_ref->{$CLID}{'Dist_Miles'};
                    $kms = $online_ref->{$CLID}{'Dist_Kms'};
                    $nmiles = $online_ref->{$CLID}{'Dist_NMs'};
                    $online_ref->{$CLID}{'Dist_Set'} = 1;
                    &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[B][COLOR=NAVY]'
                        .$online_ref->{$CLID}{'Nickname'}.'\'s[/COLOR]\sphysically\s[COLOR=BLUE]'
                        .sprintf("%.0f",$miles).'[/COLOR]\smiles\sfrom\sthe\sserver.\s([COLOR=BLUE]'
                        .sprintf("%.0f",$nmiles).'[/COLOR][/B]Nm,\s[COLOR=BLUE][B]'.sprintf("%.0f",$kms)
                        .'[/B][/COLOR]Km[B])[/B]' );
                }
            }

#           REPEAT Feature - Temperature Icon Group Reading(s)
            if ($CLIP && $online_ref->{$CLID}{'Parent'}
                && $settings_ref->{'Temperatures_On'} eq 1
                && ($online_ref->{$CLID}{'TemperatureTime'} || 0 )
                < (time - $settings_ref->{'Temperatures_Interval'})) {
                $online_ref->{$CLID}{'TemperatureTime'} = time;
                $TmpCCode = $online_ref->{$CLID}{'CCode'} || $online_ref->{$CLID}{'CCode2'};
                if ($TmpCCode) {
                    $City = $online_ref->{$CLID}{'CityALT'} || $online_ref->{$CLID}{'City'} || 'Null';
                    $Region = $online_ref->{$CLID}{'RegionALT'} || $online_ref->{$CLID}{'Region'} || 'Null';
                    $Country = $CCodeNames_ref->{$TmpCCode}{Name};
                    $cels = $online_ref->{$CLID}{'Weather-Celsius'} || 99;
                    if ($OSType =~ /Win/io) {
                        system(1,$^X,"./rbm_tools/rbm_weather.pl", $TmpCCode,
                            $clDBID,$CLID,$CLIP,$OSType,$City,$Region,$Country,
                            $cels);
                    }
                    elsif (fork() == 0) {
                        exec($^X,"./rbm_tools/rbm_weather.pl", $TmpCCode,
                            $clDBID,$CLID,$CLIP,$OSType,$City,$Region,$Country,
                            $cels);
                        exit 0;
                    }
                }
            }
            if ($online_ref->{$CLID}{'DBID'} && $CLSessionTime
                && !$online_ref->{$CLID}{'Group_Temps'}
                && !$online_ref->{$CLID}{'NOTempIcon'}
                && $Booted && $Booted < (time - 3)
                && $settings_ref->{'Temperatures_On'} ne 0
                && ($CLSessionTime / 1000) > 4 ) {
                &rbm_features::Rbm_Temperature_Update($CLID,-66,$online_ref,
                    $settings_ref,1);
                $online_ref->{$CLID}{'NOTempIcon'} = 1;
            }
            sleep 0.001 and next if exists $online_ref->{$CLID}{'DBID'};
#           --------------------------------------------------------------------
#           ---- New Client Connection -----------------------------------------
#           --------------------------------------------------------------------
            if (!$Idletime) {
#               CLIENTINFO - IF SKIPPED
                $bytes_ref = &$sub_query('clientinfo clid='.$CLID,
                    'connection_client_ip.*?error id=0 msg=ok');
                next unless $bytes_ref;
                ($Idletime,$version,$os,$Recording,$UserGroups,$Created,$TotalConnects,
                    $Away,$description,$CCode,$CLRx,$CLTx,$CLSessionTime,$CLIP) = $$bytes_ref =~
                    /client_idle_time=(\d+) .*?version=(\S+) client_platform=(\S+) .*?client_is_recording=(\d) .*?servergroups=(\S+) client_created=(\d+) .*?totalconnections=(\d+) client_away=(\d) .*?client_description([\S]*? )\S.*?client_country([\S]*? )\S.*?bytes_sent_total=(\d+).*?bytes_received_total=(\d+) .*?connected_time=(\d+) connection_client_ip=(\S+)/o;
                next unless $Idletime;
#                $os = 'Windows' unless $os;
                if ($CCode and $CCode ne ' ') {
                    $CCode =~ s/\=| //go;
                    $online_ref->{$CLID}{'CCode'} = $CCode;
                }
                else {
                    $CCode = undef;
                }
                $online_ref->{$CLID}{'UserGroups'} = $UserGroups if $UserGroups;
                $online_ref->{$CLID}{'SessionTime'} = $CLSessionTime;
                $online_ref->{$CLID}{'Channel'} = $ChanID;
            }
            next unless $UserGroups and $CLIP;
            ++$TotalClients;
            $online_ref->{$CLID}{'DBID'} = $clDBID;
            $online_ref->{$CLID}{'IP'} = $CLIP;
            $online_ref->{$CLID}{'Nickname'} = $clName;
#           RbMod - Read in FF DB Information
            &$sub_dbread($CLID);
            &$sub_log("INFO \t- TS3 Query       \t- ".$clName
                .' connected... DBID: '.$clDBID.' IP: '.$CLIP.' ONLINE: '
                .$TotalClients);
            $online_ref->{$CLID}{'TSVersion'} = $version;
            $online_ref->{$CLID}{'OS'} = $os;
            $online_ref->{$CLID}{'Created'} = $Created;
            $online_ref->{$CLID}{'TotalConnects'} = $TotalConnects;
            $online_ref->{$CLID}{'TagLineSet'} = 1 unless $Booted;
            $FFClients{$clDBID}{'ONLINE'} = time unless $FFClients{$clDBID}{'ONLINE'};
            $FFClients{$clDBID}{'LastChannel'} = $ChanID;
#           Feature - RBL Lookup
            &$sub_rbllookup($online_ref,$settings_ref,$CLID,\%FFClients,$CLIP,
                $clDBID) if $settings_ref->{'RBL_Check_On'} ne 0;
#           Feature - Clone (DBID) Detection
            &$sub_clonedet($online_ref,$CLID,$settings_ref);
#           Feature - Reconnect Flood Gauge
            &rbm_features::Rbm_JoinFlood($CLID,$online_ref,$settings_ref)
                if $settings_ref->{'OnJoin_Reconnect_Gauge_On'} ne 0;
#           Feature - DNS Lookup
            &$sub_dnslookup($CLID,$online_ref,$settings_ref);
#           GEO IP
            $GEOACTIVE = undef;
            unless ($settings_ref->{'Package_GeoIP_On'} eq 0
                or ($CLIP =~ /^(127\.|192\.168|1\.1\.1|10\.)|^172\.(\d+)/o
                and (!$2 or $2 < 16 or $2 > 31))
                or !$CCode) {
                $GEOACTIVE = 1;
                $pingable = $online_ref->{$CLID}{'Pingable'} || $CLIP;
                $pingable2 = $online_ref->{$CLID}{'Pingable2'} || $CLIP;
                $pingable3 = $online_ref->{$CLID}{'Pingable3'} || $CLIP;
                if ($OSType =~ /Win/io) {
                    system(1,$^X,"./rbm_tools/rbm_geo.pl",$CLIP,$clDBID,$CLID,
                        $CCode,$pingable,$pingable2,$pingable3,$Idletime,
                        $ChanID,$CountRead);
                }
                else {
                    if (fork() == 0) {
                        exec($^X,"./rbm_tools/rbm_geo.pl",$CLIP,$clDBID,$CLID,
                            $CCode,$pingable,$pingable2,$pingable3,$Idletime,
                            $ChanID,$CountRead);
                        exit 0;
                    }
                }
            }
#           Feature - Auto-Move
            &$sub_automove($CLID,$online_ref,$settings_ref,\%FFClients,
                $channellist_ref,$rooms_ref,$CCode,1,$GEOACTIVE)
                if $settings_ref->{'Automove_Client_OnJoin_On'} ne 0 && $Booted;
#           Feature - Welcome Back
            &$sub_wback($CLID,$online_ref,$settings_ref,$rooms_ref,\%FFClients,
                $quotes_ref,$randomwords_ref);
#           Feature - OS Detection
            &$sub_osdetect($CLID,$online_ref,$settings_ref,$groups_ref);
#           Feature - Rank
            &$sub_ranking($CLID,$online_ref,$groups_ref,$settings_ref);
#           Feature - Traceroute
            &$sub_trace($CLID,$online_ref,$settings_ref,$groups_ref,\%FFClients);
#           Feature - Status - 'Live' Icon
            &$sub_clstatus($CLID,$ChanID,$Idletime,$online_ref,$settings_ref,
                $groups_ref,1) if $settings_ref->{'Status_On'} ne 0
                && $online_ref->{$CLID}{'Parent'};
#           RbMod - Auto-Fill icon slot if no CCode found.
            &$sub_iconfill($CLID,$online_ref,$settings_ref)
                if (!defined $CCode && $settings_ref->{'Autofill_Empty_CCode_Slots_On'} ne 0);
#           RbMod - Check clients exemptions
            $Exempt = &$sub_exemptguest($CLID);
#           RbMod - Move to duplicated guest group
            if (!$Exempt) {
                &$sub_send('servergroupaddclient sgid='.$groups_ref->{'Group_Guest'}
                    .' cldbid='.$online_ref->{$CLID}{'DBID'});
                &$sub_log("INFO \t- Group Creator    \t- ".$online_ref->{$CLID}{'Nickname'}
                    .'s been added to Guest Group ID: '.$groups_ref->{'Group_Guest'});
            }
            ++$Counter;
            last;
        }
        if ($CountRead == 0) {
            $CountRead = 0;
            ++$PollTick;
            next;
        }
        if ($Counter == 0) {
            $Booted = time unless $Booted;
            unless ($BootFinished) {
                my $WordA = 'Clients';
                $WordA = 'Client' if $TotalClients == 1;
                &$sub_log(' ', 1);
                &$sub_log(('-' x 100), 1);
                &$sub_log("INFO  \t- Bootup          \t- RbMod Features loaded.", 1);
                &$sub_log("INFO  \t- Bootup          \t- ". $settings_ref->{'Query_Bot_Name'}
                    .'\'s now running. Type \'HELP\' for console commands.', 1);
                &$sub_log(('-' x 100).$nl, 1);
                unless (defined $QuiteBoot) {
                    &$sub_send('sendtextmessage targetmode=3 target=1 msg=[COLOR=BLUE][B]Finished\sLoading\s'
                    .$TotalClients.'\s'.$WordA.'.[/B][/COLOR]');
                }
                $BootFinished = 1;
            }
        }
        return ($online_ref,$badwords_ref);
    }
}

sub Rbm_Bootup_Args {
    my $numArgs = @ARGV;
    foreach my $argnum (@ARGV) {
        if ($argnum =~ /\-silent|\-quite/io) {
            $QuiteBoot = 1;
            &$sub_log("LOAD  \t- Cmd. Arguments  \t- Quite Boot-up enabled.", 1);
        }
        if ($argnum =~ /\-debug/io) {
            $Debug = 1;
            &$sub_log("LOAD  \t- Cmd. Arguments  \t- Debug enabled.", 1);
        }
    }
}

sub Rbm_Bootup {
    my $Groups_ref   = shift;
    STDOUT->autoflush(1);
    STDERR->autoflush(1);
    my ($time,$ap,$day,$date) = &Rbm_ProcessTime;
    $groups_ref = $Groups_ref;
    my $online_ref = \%online;
    my $tstamp = time().'_'.$$day.$$time.$$ap.'.log';
    $settings_ref = &Rbm_LoadConfigs('rbm_settings.cf', 1);
    $OSType = $^O;
    if ($^O !~ /Win/i) {
        $ShellColor = "\033[33m";
    }
    else {
        require Win32::Console::ANSI;
        $ShellColor = "\e[1;33m";
    }
#   Override rbm_settings.cf with command line arguments.
    &Rbm_Bootup_Args;
    &Rbm_CheckUserColor($settings_ref->{'Console_Text_Color'});
    if ($settings_ref->{'Check_For_Updates_On'} ne 0) {
        &rbm_features::Check4Update;
    }
    if ($settings_ref->{'Logging_On'} == 1) {
        open($LOG, ">>",'rbm_logs/rbmod_'.$tstamp) or &Rbm_MKLogs(\$!,\$tstamp);
        flock($LOG, 2);
        $Logging = 1;
    }
    &$sub_log("INFO  \t- System         \t- Detected ". ucfirst($OSType) .' Operating System.', 1);
    &$sub_log("LOAD  \t- Logs Creator      \t- Creating Log File...", 1);
    &$sub_log("OK    \t- Logs Creator      \t- rbm_logs\/rbmod_".$tstamp.' Created.', 1);
    &$sub_log("LOAD  \t- Config Files   \t- Checking Configuration Files...", 1);
    $settings_ref = &Rbm_LoadConfigs('rbm_settings.cf');
    $q_responses_ref = &Rbm_LoadConfigs('rbm_extras/rbm_botresponses.cf');
    $gameicons_ref = &Rbm_LoadConfigs('rbm_extras/rbm_triggers.cf');
    $badwords_ref = &Rbm_LoadConfigs('rbm_extras/rbm_badwords.cf');
    $randomwords_ref = &Rbm_LoadConfigs('rbm_extras/rbm_funwords.cf');
    $quotes_ref = &Rbm_LoadConfigs('rbm_extras/rbm_quotes.cf');
    $goodbyes_ref = &Rbm_LoadConfigs('rbm_extras/rbm_goodbye.cf');
    &$sub_log("DONE  \t- Config Files   \t- Configuration Files Loaded.", 1);
    $BotName_ref = &$sub_cleantext($settings_ref->{'Query_Bot_Name'});
#   Connect second TS3 socket
    my @Sockets;
    my ($sockA,$Bot2CLID,$botDBID) = &Rbm_Sock(0);
    push(@Sockets, $sockA);
    push(@BOTCLIDs, $Bot2CLID);
    &Rbm_Connect; # Connect main socket of RbMod to the TS3 server port.
#   Monitor secondary MOD socket
    &Rbm_MonitorSocket($sockA,undef,1,$settings_ref);
#   REMOTE CONTROL HOST - GUI Application, remarked until complete.
#    &Rbm_RemoteControl_Host;
    if ($settings_ref->{'WebServer_On'} ne 0) {
        &$sub_log("INFO \t- WebServer       \t- Starting Web Server...");
        &Rbm_WebServer($sockA);
    }
    if ($settings_ref->{'Channel_Watch_Bot_Count'}
        && ($settings_ref->{'Channel_Watch_On'} ne 0)
        && $settings_ref->{'Channel_Watch_Bot_Count'} =~ /\d+/o) {
        for (my $i=2; $i <= ($settings_ref->{'Channel_Watch_Bot_Count'} + 1); $i++) {
            my ($Socks,$bCLID,$bDBID) = &Rbm_Sock($i);
            next unless $Socks && $bCLID;
            push(@Sockets, $Socks);
            push(@BOTCLIDs, $bCLID);
            $botDBID = $bDBID unless $botDBID;
#           Monitor secondary MOD socket
            &Rbm_MonitorSocket($Socks,1,$i,$settings_ref);
        }
    }
    &Rbm_CleanLogs; # Remove dormant log files on HDD.
    &Rbm_CleanGroups; # Remove dormant groups from previous bootup.
    &Rbm_Instanceinfo; # Populate variables for RbMod.
    &Rbm_AddGroups; # Add RbMod groups to TS3 server / clients.
    &$sub_log("INFO \t- IRC Bot          \t- Launching IRC Bot...", 1)
        if $settings_ref->{'IRC_Bot_On'} ne 0;
    &Rbm_IRC; # Launch IRC Bot.
    &$sub_log(' ', 1);
    &$sub_log(('-' x 100), 1);
    &$sub_log("DONE \t- Bootup           \t- RbMod Engine Loaded.", 1);
    &$sub_log("DONE \t- Bootup           \t- Initializing RbMod Features...", 1);
    &$sub_log(('-' x 100).$nl, 1);
#   Obtain default channel admin group
    my $results_ref = &$sub_query('serverinfo',
        'virtualserver_default_channel_admin_group=\d+.*?error id=0 msg=ok');
    if ($results_ref) {
        my ($VName,$VWMSG,$TS3Version);
        ($VName,$VWMSG,$TS3Version,$ChanAdminID) = $$results_ref =~ /virtualserver_name=(\S+) virtualserver_welcomemessage=(\S+) .*?virtualserver_version=(\S+) .*?virtualserver_default_channel_admin_group=(\d+)/o;
        $settings_ref->{'ServName'} = $VName;
        $settings_ref->{'VWMSG'} = $VWMSG;
        $settings_ref->{'TS3Version'} = $TS3Version;
        &$sub_log("INFO \t- Discovery          \t- Virtual Server Default Channel Admin Group ID: ".$ChanAdminID, 1);
    }
#   Flat File Database Setup
    $FFChans  = &Rbm_ChannelDeleteLoadFF(\%rooms);
    &Rbm_ClientInfoLoadFF(\%FFClients);
    return (\%rooms,$settings_ref,$FFChans,$badwords_ref,$randomwords_ref,
        \@BOTCLIDs,\%FFClients);
}

sub Rbm_Connect {
    $settings_ref = &Rbm_LoadConfigs('rbm_settings.cf');
#   SOCKET
    &Rbm_Socket(
        $settings_ref,
        $$BotName_ref,
        $settings_ref->{'Query_Login'},
        $settings_ref->{'Query_Address'},
        $settings_ref->{'Query_Password'},
        $settings_ref->{'Query_Port'},
        $settings_ref->{'Query_Virtual_Server_Port'}
    );
    $sock->autoflush(1);
#   WHOAMI
    my $whoami_ref = &$sub_query('whoami',
            'virtualserver_status.*?error id=0 msg=ok');
    unless ( $whoami_ref && $$whoami_ref =~ /virtualserver_status/ ) {
        &$sub_log("ERROR \t- SHUTDOWN          \t- Couldn't query WHOAMI!", 1);
    }
    else {
        my ($BotCLID,$BotCHID,$BotDBID) = $$whoami_ref
            =~ /client_id=(\d+) client_channel_id=(\d+).*?database_id=(\d+)/o;
        $settings_ref->{'BotCLID'} = $BotCLID;
        $settings_ref->{'BotCHID'} = $BotCHID;
        $settings_ref->{'BotDBID'} = $BotDBID;
        $settings_ref->{'BootupTime'} = time;
        $settings_ref->{'OSType'} = $OSType;
    }
    $Cnt = 0;
    sleep 0.25;
}

sub Rbm_Instanceinfo {
    my ($max_query_cmds,$max_query_time,$setme) = (500, 2);
    my $instanceinfo_ref = &$sub_query('instanceinfo',
            'serverinstance_database_version');
    unless ( $instanceinfo_ref ) {
        &$sub_log("ERROR \t- TS3 Query         \t- Couldn't query Instanceinfo!");
        return;
    }
    if ($$instanceinfo_ref =~ /error id=([^0]\d+) msg=(\S+)/) {
        return;
    }
    elsif ($$instanceinfo_ref =~ /serverinstance_serverquery_flood_commands=(\d+)/) {
        my $old_cmds = $1;
        if ($old_cmds < $max_query_cmds) {
            &$sub_log("WARN \t- TS3 Query        \t- Serverquery Flood Commands: ".$old_cmds, 1);
            &$sub_log("INFO \t- TS3 Query        \t- It\'s recommended you increase this to ".$max_query_cmds.' or more.', 1);
            print "\t\t\t\t\t\tINFO\t- Press ENTER to use ".$max_query_cmds.' or change to: ';
            my $userinput = <STDIN>;
            chomp($userinput);
            $max_query_cmds = $userinput if $userinput;
            &$sub_send( 'instanceedit serverinstance_serverquery_flood_commands='.$max_query_cmds );
            &$sub_send( 'instanceedit serverinstance_serverquery_flood_time='.$max_query_time );
            &$sub_log("SET\t- TS3 Query         \t- Serverquery Flood Commands: ".$max_query_cmds, 1);
            &$sub_log("SET\t- TS3 Query         \t- Serverquery Flood Time: ".$max_query_time, 1);
            return;
        }
        else {
            &$sub_log("OK    \t- TS3 Query     \t- Serverquery Flood Commands: ".$max_query_cmds, 1);
            &$sub_log("OK    \t- TS3 Query     \t- Serverquery Flood Time: ".$max_query_time, 1);
            return;
        }
    }
}

sub Rbm_STDINCapture {
    my ($Input,$settings_ref,$Pid) = @_;
    chomp($Input);
    my $Color = $ShellColor;
    if ( $Input =~ /stop|shutdown|exit|quit|close/io ) {
        &$sub_log("INFO \t- SHUTDOWN       \t\- Stopping Responsive Bot Modification...", 1);
        &Rbm_CleanGroups(1);
        &Rbm_Cleanup;
    }
    elsif ( $Input =~ /cleanup/io ) {
        &$sub_log("INFO \t- CLEANER       \t\- Cleaning all client icon slots...", 1);
        &Rbm_CleanGroups(1,1);
        &Rbm_ParentCaching('Traffic_Meter_On',undef,'Settings');
    }
    elsif ( $Input =~ /setting (\S+)\=(\S+)/io ) {
#        &$sub_log("INFO \t- rbm_settings     \t\- Cleaning all client icon slots...", 1);
        &Rbm_ParentCaching($1,$2,'Settings');
    }
    elsif ( $Input =~ /help/io ) {
        say $nl."\t" x 1 . $Color."Commands:";
        say $nl."\t" x 1 . $Color."Quit      \t(Or Stop,Exit,Close,Shutdown)\t\t\t- Shutdown and cleanup all TS3 groups with icons";
        say "\t" x 1 . $Color."Cleanup      \t\t\t\t\t\t\t- Cleanup client icon slots (After using the traffic meter.)";
        say "\t" x 1 . $Color."Setting <Variable>=<Value>     \t\t\t\t\t- Change individual Rbm_settings.cf variables while the mods running.";
        say "\t" x 1 . $Color."Reset      \t\t\t\t\t\t\t- Reload new changes from rbm_settings.cf";
        say "\t" x 1 . $Color."Reload      \t\t\t\t\t\t\t- Reload Mod and any new changes from rbm_settings.cf";
        say "\t" x 1 . $Color."Debug <on/off>\t\t\t\t\t\t\t- Display Mod Logging here in the console.";
        say "\t" x 1 . $Color."Help      \t\t\t\t\t\t\t- Display this help screen.";
        say "\t" x 1 . $Color."Color <Name>\t(Red,Green,Yellow,Blue,Magenta,Cyan,White)\t- Change Console Text Color.";
        say "\t" x 1 . $Color."Say <Message>\t\t\t\t\t\t\t- Send a global message to teamspeak.".$nl;
    }
    elsif ( $Input =~ /^say /oi ) {
        $Input =~ s/^say //oi;
        $Input = &$sub_cleantext($Input);
        &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[COLOR=BLUE]'.$$Input.'[/COLOR]' );
    }
    elsif ( $Input =~ /^color (\S+)/io ) {
        &Rbm_CheckUserColor($1);
        $Color = $ShellColor;
    }
    &Rbm_ParentCaching('Debug',$1) && sleep 1 if $Input =~ /^debug (\S+)/io;
    if ( $Input =~ /^reset/i ) {
        &Rbm_ParentCaching('Reset');
        &Rbm_IRC unless exists $settings_ref->{'IRC_Bot_Launched'};
        &Rbm_CheckUserColor( $settings_ref->{'Console_Text_Color'} );
        sleep 1;
    }
    elsif ( $Input =~ /^reload/i ) {
        &Rbm_ParentCaching('Reload');
        sleep 1;
    }
    eval {
        print STDOUT "\r".$Color.($settings_ref->{'Query_Bot_Name'}).'> ';
    };
}

sub Rbm_BytesToMBytes($) {
    my $c = shift || return 0;
    $c >= 1073741824 ? sprintf("%0.2f\\sGBytes", $c/1073741824)
        : $c >= 1048576 ? sprintf("%0.2f\\sMBytes", $c/1048576)
        : $c >= 1024 ? sprintf("%0.2f\\sKBytes", $c/1024)
        : $c . "\\sbytes";
}

sub Rbm_RandomPassword {
    my $password_length = $_[0];
    my ($password,$rand);
    if (!$password_length) {
        $password_length = 15;
    }
    my @chars = split( " ",
        "a b c d e f g h i j k l m n o p q r s t u v w x y z
         A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
         0 1 2 3 4 5 6 7 8 9 ~ - _" );
    srand;
    for (my $i=0; $i <= $password_length ;$i++) {
        $rand = int(rand 65);
        $password .= $chars[$rand];
    }
    return \$password;
}

sub Rbm_ParentCaching {
    my ($Peram,$Value,$Settings) = @_;
    if ( $Value and $Value =~ /Yes|On|1/goi) {
        $Value = 1;
    }
    else {
        $Value = 0;
    }
    $Peram = 'Settings-'.$Peram if $Settings;
#    say $Value;
    open(my $CACHE, ">>",'rbm_stored/rbm_cache.cf')
            or die "ERROR\t- Parent Process\t- Couldn\'t Load rbm_cache.cf: ".$!;
    syswrite $CACHE, 'PARENT '.$Peram.'='.$Value.'|';
    close $CACHE;
}

sub Rbm_IRC {
    return if $settings_ref->{'IRC_Bot_On'} eq 0;
    $settings_ref->{'IRC_Bot_Launched'} = 1;
    if ($OSType =~ /Win/io) {
        system(1,$^X,"./rbm_tools/rbm_irc.pl", $settings_ref->{'IRC_Bot_Label'},
            $settings_ref->{'IRC_Bot_Server'},$settings_ref->{'IRC_Bot_Port'},
            $settings_ref->{'IRC_Bot_Nick'},$settings_ref->{'IRC_Bot_Nick_Alternative'},
            $settings_ref->{'IRC_Bot_Login'},$settings_ref->{'IRC_Bot_Channels'},
            $settings_ref->{'IRC_Bot_AutoOp'},$settings_ref->{'IRC_Bot_AutoVoice'});
    }
    else {
        if (fork() == 0) {
            exec($^X,"./rbm_tools/rbm_irc.pl", $settings_ref->{'IRC_Bot_Label'},
                $settings_ref->{'IRC_Bot_Server'},
                $settings_ref->{'IRC_Bot_Port'},
                $settings_ref->{'IRC_Bot_Nick'},
                $settings_ref->{'IRC_Bot_Nick_Alternative'},
                $settings_ref->{'IRC_Bot_Login'},
                $settings_ref->{'IRC_Bot_Channels'},
                $settings_ref->{'IRC_Bot_AutoOp'},
                $settings_ref->{'IRC_Bot_AutoVoice'});
            exit 0;
        }
    }
}

sub Rbm_CheckCache {
    my $online_ref = \%online;
    my $FFClients_ref = \%FFClients;
    my $CacheFile = 'rbm_stored/rbm_cache.cf';
    return $settings_ref unless -e $CacheFile;
    open(my $CACHE, "<".$CacheFile) or die $!;
    flock($CACHE, 2);
    my $Cached = <$CACHE>;
    flock($CACHE, 8);
    close $CACHE;
    unlink $CacheFile;

    return $settings_ref unless $Cached;
    my @cached = split /\|/,$Cached;
    my ($new,$line,@array);

    foreach $new (@cached) {
        if ( $new =~ /GRSS\=(.*?)$/so ) {
            my ($RSSdata,$CLIDs) = $1;
            $RSSdata =~ s/ /\\s/go;
            push @array, $1 while ($RSSdata =~ /(.{1,940})/msxog);
            foreach $line (@array) {
                if ($settings_ref->{'RSS_Global_Chat_Feed'} ne 0) {
                    &$sub_send('sendtextmessage targetmode=3 target=1 msg=[COLOR=MAROON]'
                        .$line.'[/COLOR]');
                }
            }
            if ($settings_ref->{'RSS_Private_Chat_Feed'} ne 0) {
                foreach $CLIDs (keys %$online_ref) {
                    foreach $line (@array) {
                        &$sub_send('sendtextmessage targetmode=1 target='
                            .$CLIDs.' msg=[COLOR=MAROON]'.$line.'[/COLOR]');
                    }
                    sleep 0.3;
                }
            }
        }
        if ( $new =~ /IRC\=(.*?)$/so ) {
            my $IRCdata = $1;
            push @array, $1 while ($IRCdata =~ /(.{1,950})/msxog);
            foreach $line (@array) {
                $line =~ s/ /\\s/go;
                &$sub_send('sendtextmessage targetmode=3 target=1 msg=[COLOR=MAROON]'
                    .substr($line,0,1020).'[/COLOR]');
            }
        }
#       Check for completed traceroutes
        if ( $new =~ /DBID\=(\d+) CLID\=(\d+) HPS\=(\d+) HPR\=(\d+) PATH=(\S+) PNG\=(\S+) PNG2\=(\S+) PNG3\=(\S+)/so ) {
            $FFClients_ref->{$1}{'Hops'} = $3;
            $FFClients_ref->{$1}{'HopsRead'} = $4;
            $FFClients_ref->{$1}{'HopsPath'} = $5;
            $online_ref->{$2}{'Pingable'} = $6;
            $online_ref->{$2}{'Pingable2'} = $7;
            $online_ref->{$2}{'Pingable3'} = $8;
            if ( exists $online_ref->{$2} ) {
                &rbm_features::Rbm_SetupTrace($online_ref,$settings_ref,$2,$3);
                &rbm_features::Rbm_DisplayTrace($online_ref,$settings_ref,$2,$3,$5);
            }
        } # Check for completed DNS lookups
        if ( $new =~ /DBID\=(\d+) CLID\=(\d+) DNS\=(\S+)/so ) {
            my ($DBID,$CLID,$DNS) = ($1,$2,$3);
            $DNS =~ s/\.$//;
            $online_ref->{$CLID}{'DNS'} = $DNS;
            $FFClients_ref->{$DBID}{'DNS'} = $DNS;
            $FFClients_ref->{$DBID}{'DNSCached'} = 1;
#           Client online still?
            if ( exists $online_ref->{$CLID} ) {
                &rbm_features::Rbm_SetupDNS($CLID,$online_ref,$settings_ref,
                        $FFClients_ref);
            }
        } # Check for completed Ping results
        if ( $new =~ /DBID\=(\d+) CLID\=(\d+) CURRENTPING\=(\d+)/so ) {
            &rbm_features::Rbm_ReadPings($2,$3,$online_ref,$settings_ref,
                    $FFClients_ref);
        } # Check for Temperatures
        if ( $new =~ /DBID\=(\d+) CLID\=(\d+) READCELSIUS\=(\S+)/so ) {
            if ( !exists $online_ref->{$2}{'CelsiusRounded'} ) {
                &$sub_send( 'sendtextmessage targetmode=1 target='
                    .$2.' msg=[COLOR=BLUE]The\stemperature\sfor\syour\slocation\s[/COLOR][COLOR=NAVY][B]'
                    .($online_ref->{$2}{'City'} || $online_ref->{$2}{'CityALT'} || '')
                    .'[/B][/COLOR][COLOR=NAVY][B],\s'.($online_ref->{$2}{'Region'} || $online_ref->{$2}{'RegionALT'} || '').'[/B][/COLOR][COLOR=BLUE]\sfound.[/COLOR]');
            }
            &rbm_features::Rbm_Temperature_Update($2,$3,$online_ref,$settings_ref);
        }
        if ( $new =~ /DBID\=(\d+) CLID\=(\d+) REGION\=(\S+) CITY\=(\S+) CODE\=(\S+) LONG=(\S+) LAT=(\S+) IDLETIME\=(\S+) CHANID\=(\S+)/so ) {
            my ($DBID,$CLID,$Region,$City,$CCode,$longitude,$latitude,$Idletime,
                $ChanID) = ($1,$2,$3,$4,$5,$6,$7,$8,$9);
            my $rooms_ref = \%rooms;
            if ($City =~ /\-ALT/o and !exists $online_ref->{$CLID}{'CityALT'} ) {
                $Region =~ s/\-ALT//o;
                $City =~ s/\-ALT//o;
#                say 'Setting Alternative Region / City for '.$online_ref->{$CLID}{'Nickname'}.' - '.$Region. ' '.$City;
                $online_ref->{$CLID}{'RegionALT'} = $Region if $Region && $Region ne 'Null';
                $online_ref->{$CLID}{'CityALT'} = $City if $City && $City ne 'Null';
                &$sub_send('sendtextmessage targetmode=1 target='
                    .$CLID.' msg=[COLOR=BLUE]Unfortunately\sthe\snearest\stemperature\sfor\syour\slocation\scame\sfrom\s[/COLOR][COLOR=NAVY][B]'
                    .$City.'[/B][/COLOR][COLOR=BLUE],\s[/COLOR][COLOR=NAVY][B]'
                    .$Region.'[/B][/COLOR][COLOR=BLUE].[/COLOR]');
            }
            elsif ($ChanID and exists $online_ref->{$CLID}{'IP'}) {
                unless ($settings_ref->{'Package_Weather_Underground_On'} eq 0
                    or ($online_ref->{$CLID}{'IP'} =~ /^(127\.|192\.168|1\.1\.1|10\.)|^172\.(\d+)/o
                        and (!$2 or $2 < 16 or $2 > 31))
                    or exists $online_ref->{$CLID}{'City'} ) {
#                    say 'GO';
                    &$sub_send( 'sendtextmessage targetmode=1 target='
                        .$CLID.' msg=[COLOR=BLUE]Please\swait\swhile\sI\scalculate\sthe\stemperature\sfor\s[/COLOR][COLOR=NAVY][B]'
                        .$City.'[/B][/COLOR][COLOR=BLUE],\s[/COLOR][COLOR=NAVY][B]'
                        .$Region.'[/B][/COLOR][COLOR=BLUE].[/COLOR]');
                    my $Country = $CCodeNames_ref->{$CCode}{Name};
                    my $pause = 0;
#                    say $CCode,$online_ref->{$CLID}{'DBID'},$CLID,$online_ref->{$CLID}{'IP'},$OSType,$City,$Region,$Country,$pause;

#                    $pause = $TotalClients unless $Booted;
                    if ($OSType =~ /Win/io) {
                        system(1,$^X,"./rbm_tools/rbm_weather.pl",$CCode,
                            $online_ref->{$CLID}{'DBID'},$CLID,
                            $online_ref->{$CLID}{'IP'},$OSType,$City,$Region,
                            $Country,'',$pause);
                    }
                    elsif (fork() == 0) {
                        exec($^X,"./rbm_tools/rbm_weather.pl",$CCode,
                            $online_ref->{$CLID}{'DBID'},$CLID,
                            $online_ref->{$CLID}{'IP'},$OSType,$City,$Region,
                            $Country,'',$pause);
                        exit 0;
                    }
                }
                $online_ref->{$CLID}{'Region'} = $Region if $Region && $Region ne 'Null';
                $online_ref->{$CLID}{'City'} = $City if $City && $City ne 'Null';
                $online_ref->{$CLID}{'CCode2'} = $CCode if $CCode && $CCode ne 'Null';
                &$sub_automove($CLID,$online_ref,$settings_ref,\%FFClients,
                    $channellist_ref,$rooms_ref,$CCode)
                    if $settings_ref->{'Automove_Client_OnJoin_On'} ne 0 && $Booted;
                &$sub_clstatus($CLID,$ChanID,$Idletime,$online_ref,$settings_ref,
                    $groups_ref,2 ) if $settings_ref->{'Status_On'} ne 0;
                if ( $settings_ref->{'Autofill_Empty_CCode_Slots_On'} ne 0 && !$online_ref->{$CLID}{'CCode'}
                    && $online_ref->{$CLID}{'CCode2'} ) {
                    &$sub_iconfill($CLID,$online_ref,$settings_ref,$online_ref->{$CLID}{'CCode2'});
                }
                if ($longitude && $longitude ne 'Null' && $Booted
                    and $settings_ref->{'Distance_Calculator_On'} ne 0) {
                    my $lat_local  = $settings_ref->{'Distance_Calculator_Server_Latitude'};
                    my $long_local = $settings_ref->{'Distance_Calculator_Server_Longitude'};
                    my $miles = &rbm_features::Rbm_Distance_main($latitude, $longitude, $lat_local, $long_local, 'M');
                    my $kms = &rbm_features::Rbm_Distance_main($latitude, $longitude, $lat_local, $long_local, 'K');
                    my $nmiles = &rbm_features::Rbm_Distance_main($latitude, $longitude, $lat_local, $long_local, 'N');
                    $online_ref->{$CLID}{'Dist_Miles'} = $miles;
                    $online_ref->{$CLID}{'Dist_Kms'} = $kms;
                    $online_ref->{$CLID}{'Dist_NMs'} = $nmiles;
                }
            }
#            else {
#                $online_ref->{$CLID}{'RegionALT'} = $Region;
#                $online_ref->{$CLID}{'CityALT'} = $City;
#            }
        }
        if ( $new =~ /DBID\=(\d+) CLID\=(\d+) COND\=(\S+) CELS\=(\S+) FAHR\=(\S+) CODE\=(\S+)/so ) {
            my ($DBID,$CLID,$Conditions,$Celsius,$Fahrenheit,$CCode) = ($1,$2,$3,$4,$5,$6);
            $online_ref->{$CLID}{'CCode2'} = $CCode if $CCode;
            if ($Celsius eq 'Null' and $Fahrenheit ne 'Null') {
                $Celsius = sprintf "%.0f", ($Fahrenheit - 32) * 5/9;
            }
#            if ( exists $online_ref->{$CLID}{'Nickname'} ) {
                $online_ref->{$CLID}{'Weather-Conditions'} = $Conditions if $Conditions ne 'Null';
                $online_ref->{$CLID}{'Weather-Celsius'} = $Celsius;
                $online_ref->{$CLID}{'Weather-Fahrenheit'} = $Fahrenheit if $Fahrenheit ne 'Null';
                &rbm_features::Rbm_Temperature_Update($CLID,$Celsius,$online_ref,
                        $settings_ref,1);
#            }
        }
        if ( $new =~ /DBID\=(\d+) CLID\=(\d+) RBL\=(\S+) SRV\=(\S+)/so ) {
            my ($DBID,$CLID,$Data,$SRV) = ($1,$2,$3,$4);
            if ($Data && $Data =~ /\d+\.\d+\.\d+\.\d+/so) {
                my $msg;
                &$sub_log("INFO  \t- RBL Lookup        \t- Found IP ".$Data.' blacklisted on '.$SRV.'!');
                &$sub_send( 'sendtextmessage targetmode=3 target=1 msg=[B][COLOR=RED]RBL\sLookup\s-[/COLOR][COLOR=MAROON]\sDetected\s[/COLOR][COLOR=BLUE]'
                    .$online_ref->{$CLID}{'Nickname'}.'[/COLOR][COLOR=MAROON]\sIP\saddress\slisted\son\sRBL\sserver\s[/COLOR][COLOR=NAVY]'
                    .$SRV.'[/COLOR][COLOR=MAROON]![/COLOR][/B]');

                if ( $settings_ref->{'RBL_Ban_Punish_Reason'} !~ /Default/io ) {
                    $msg = &$sub_cleantext( $settings_ref->{'RBL_Ban_Punish_Reason'} );
                    &$sub_send( 'banadd ip='.$Data.' time=0 banreason='.$$msg );
                }
                else {
                    $msg = $settings_ref->{'RBL_Server'}.'\sBlacklisted!';
                    &$sub_send( 'banadd ip='.$Data.' time=0 banreason='.$msg );
                }
            }
            $FFClients_ref->{$DBID}{'RBLRead'} = time;
        }
        if ($new =~ /notifyclientleftview.+?invokerid=\d+/so) { # Check kicked
            my ($cfid,$ctid,$reasonid,$invokerid,$reasonmsg,$clid) = $new =~ /cfid=(\d+) ctid=(\d+) reasonid=(\d+) invokerid=(\d+) invokername=\S+ invokeruid=\S+ reasonmsg(\=\d+)? clid=(\d+)/o;
            next unless $invokerid;
            my $InvokerDBID = $online_ref->{$invokerid}{'DBID'};
            my $kickedDBID = $online_ref->{$clid}{'DBID'};
            my $kickedGroups = $online_ref->{$clid}{'UserGroups'};
            my $SET_GroupProtectedList = $settings_ref->{'Group_Protected_GroupID_MemberIDs'};
            my @ProtectList = $SET_GroupProtectedList =~ /([\d]*\-[\>]?\[.+?\])\,?/sgo;
            my ($raw,$Group,$Clients,@ProtectIDs,$GroupID,$ProtectedDBID,$KickReason);
            my $SET_GroupProtectedKick = $settings_ref->{'Group_Protected_Kick'};
            my $SET_GroupProtectedBan = $settings_ref->{'Group_Protected_Ban'};
            my $SET_GroupProtectedBanDuration = $settings_ref->{'Group_Protected_Ban_Duration'};
            my $SET_GroupProtectedBanReason = $settings_ref->{'Group_Protected_Ban_Reason'};
#           Check to see if invoker's exempt first
            foreach $raw (@ProtectList) {
                ($Group,$Clients) = $raw =~ /([\d]*)\-[\>]?\[(.+?)\]/sgo;
                @ProtectIDs = split /\,/o, $Clients;
                foreach $ProtectedDBID (@ProtectIDs) {
                    if ($InvokerDBID && $ProtectedDBID && $InvokerDBID == $ProtectedDBID) {
                        next;
                    }
                }
            }
#           Check to see if kicked client is protected now
            foreach $raw (@ProtectList) {
                ($Group,$Clients) = $raw =~ /([\d]*)\-[\>]?\[(.+?)\]/sgo;
                @ProtectIDs = split /\,/o, $Clients;
                foreach $ProtectedDBID (@ProtectIDs) {
                    if ($kickedDBID && $kickedDBID == $ProtectedDBID) {
                        if ($SET_GroupProtectedBanReason =~ /default/io) {
                            $SET_GroupProtectedBanReason = 'Never\stouch\smy\sfriends!';
                        }
                        else {
                            my $retrieve = &$sub_cleantext($SET_GroupProtectedBanReason);
                            $SET_GroupProtectedBanReason = $$retrieve;
                        }
                        if ($SET_GroupProtectedBan ne 0) {
                            &$sub_send('banadd ip='.$online_ref->{$invokerid}{'IP'}.' time='
                                .$SET_GroupProtectedBanDuration.' banreason='.$SET_GroupProtectedBanReason);
                            &$sub_send('clientkick clid='.$invokerid
                                .' reasonid=5 reasonmsg='.$SET_GroupProtectedBanReason);
                        }
                        if ($SET_GroupProtectedKick ne 0) {
                            &$sub_send('clientkick clid='.$invokerid
                                .' reasonid=5 reasonmsg='.$SET_GroupProtectedBanReason);
                        }
                        next;
                    }
                }
            }
        }
        elsif ( $new =~ /PARENT (\S+)\=([\S]+?)/so ) {
            my ($Peram,$Value) = ($1,$2);
            sub Rbm_whoami {
                my $NEWsettings_ref = &Rbm_LoadConfigs('rbm_settings.cf');
                my $whoami_ref = &$sub_query('whoami','virtualserver_status.*?error id=0 msg=ok');
                unless ($whoami_ref) {
                    &$sub_log("ERROR \t- TS3 Query          \t- Couldn't query whoami!");
                    return $settings_ref;
                }
                my $results_ref = &$sub_query('serverinfo',
                    'virtualserver_default_channel_admin_group=\d+.*?error id=0 msg=ok');
                if ($results_ref) {
                    my ($VName,$VWMSG,$TS3Version,$ChanAdminID) = $$results_ref =~ /virtualserver_name=(\S+) virtualserver_welcomemessage=(\S+) .*?virtualserver_version=(\S+) .*?virtualserver_default_channel_admin_group=(\d+)/o;
                    $NEWsettings_ref->{'ServName'} = $VName;
                    $NEWsettings_ref->{'VWMSG'} = $VWMSG;
                    $NEWsettings_ref->{'TS3Version'} = $TS3Version;
                }
                my ($BotCLID,$BotCHID,$BotDBID) = $$whoami_ref =~ /client_id=(\d+) client_channel_id=(\d+).*?database_id=(\d+)/so;
                return $settings_ref unless $BotCLID;
                $NEWsettings_ref->{'BotCLID'} = $BotCLID;
                $NEWsettings_ref->{'BotCHID'} = $BotCHID;
                $NEWsettings_ref->{'BotDBID'} = $BotDBID;
                $NEWsettings_ref->{'BootupTime'} = time;
                $NEWsettings_ref->{'OSType'} = $^O;
                my $SET_ConsoleTextColor = $NEWsettings_ref->{'Console_Text_Color'};
                &Rbm_CheckUserColor($SET_ConsoleTextColor);
                return ($NEWsettings_ref);
            }
            if ($Peram =~ /Settings-/sio) {
                $Peram =~ s/Settings\-//go;
                say 'Changing setting '.$Peram.' = '.$Value;
                $settings_ref->{$Peram} = $Value;
                return ($settings_ref);
            }
            elsif ($Peram =~ /^debug/sio) {
                $Debug = $Value;
                say 'Debugging now '.$Value;
            }
            elsif ($Peram =~ /StopSocket/sio) {
                &Rbm_Disconnect();
            }
            elsif ($Peram =~ /StartSocket/sio) {
                &Rbm_Connect();
                $settings_ref = &Rbm_whoami();
            }
            elsif ($Peram =~ /Reconnect/so) {
                &Rbm_Disconnect();
                &Rbm_Connect();
                $settings_ref = &Rbm_whoami();
            }
            elsif ($Peram =~ /^reload/sio) {
                &Rbm_CleanGroups();
                &Rbm_Disconnect();
                sleep 1;
                $TotalClients = 0;
                &Rbm_Connect();
                &Rbm_AddGroups();
                $settings_ref = &Rbm_whoami();
                return ($settings_ref, 1);
            }
            elsif ($Peram =~ /^reset/sio) {
                $settings_ref = &Rbm_whoami();
                return ($settings_ref, 1);
            }
            elsif ($Peram =~ /^DBReload/sio) {
                return ($settings_ref, undef, 1);
            }
            elsif ($Peram =~ /SaveApply/sio) {
                $settings_ref = &Rbm_whoami();
            }
        }
    }
    return ($settings_ref);
}

sub Rbm_Monitor {
    my ($groups,$clientlist_ref) = @_;
    my $FFClients_ref = \%FFClients;
    my $a = \%online;
    my (@QueueDelete,$Deletekey,$key,$result,$bytes_ref,$DBID,$random);
    my $Features_ref = \%rbm_features::Features;
    unless ($clientlist_ref) {
        &$sub_log("ERROR \t- TS3 Query           \t- Couldn't query the clientlist! (2)");
        return;
    }
    foreach $key (keys %$a) {
        ($result) = $$clientlist_ref =~ /clid=($key) /;
        if (!exists $a->{$key}{'Nickname'}) {
            push(@QueueDelete, $key);
            next;
        }
#       Confirm Client Disconnects
        unless (defined $result) {
            $bytes_ref = &$sub_query('clientinfo clid='.$key,
                'connection_client_ip.*?error id=0 msg=ok');
            next if defined $bytes_ref;
            $DBID = $a->{$key}{'DBID'};
            next unless defined $DBID;
            push(@QueueDelete, $key);
            delete $FFClients{$DBID}{'ONLINE'};
#           Random Good bye message.
            if ($a->{$key}{'TotalConnects'} =~ /[369]$/o
                && (($a->{$key}{'LastOnline'} || 0) < (time - 10)) ) {
                $random = @$goodbyes_ref[rand @$goodbyes_ref];
                $random = &$sub_cleantext($random);
                $PartMsgs{$key}{'Msg'} = $$random || 1;
                $PartMsgs{$key}{'Time'} = time;
            }
            unless (exists $a->{$key}{'Clones'} || !exists $a->{$key}{'Parent'}) {
                $a->{$key}{'LastOnline'} = time;
                $FFClients{$DBID}{'Disconnected'} = 1;
                &$sub_dbwrite($key);
            }
#           Update existing clone information
            &$sub_clonedet($a,$key,$settings_ref,1);
#           Cleanup Groups &$sub_clonedet
            $gameicons_ref = &$sub_NowPlaying(undef,$key,$settings_ref,
                $gameicons_ref,\%online,\%NowPlaying,'Stop');

            if (exists $a->{$key}{'Group_Temps'} and exists $a->{$key}{'CelsiusRounded'}) {
                my $rounded = $a->{$key}{'CelsiusRounded'};
                --$Features_ref->{'Temp'.$rounded}{'Users'} if $Features_ref->{'Temp'.$rounded}{'Users'};
                if (exists $Features_ref->{'Temp'.$rounded}
                    && $Features_ref->{'Temp'.$rounded}{'Users'} < 1) {
                    &$sub_send('servergroupdel sgid='.$a->{$key}{'Group_Temps'}.' force=1');
                    &$sub_log("INFO  \t- TS3 Query        \t- Removed entire Temperature GroupID: "
                        .$a->{$key}{'Group_Temps'});
                    delete $Features_ref->{'Temp'.$rounded};
                }
                else {
                    &$sub_send('servergroupdelclient sgid='
                        .$a->{$key}{'Group_Temps'}.' cldbid='.$DBID);
                    &$sub_log("INFO  \t- TS3 Query        \t- ".$a->{$key}{'Nickname'}
                        .' Removed from Temperature GroupID: '.$a->{$key}{'Group_Temps'});
                }
                sleep 0.01;
            }
            next if !exists $a->{$key}{'Parent'};
            if (exists $a->{$key}{'Group_Rank'} && exists $a->{$key}{'Rank'}) {
                my $rank = $a->{$key}{'Rank'};
                --$Features_ref->{'Rank'.$rank}{'Users'};
                if (exists $Features_ref->{'Rank'.$rank}
                    && $Features_ref->{'Rank'.$rank}{'Users'} < 1) {
                    &$sub_send('servergroupdel sgid='.$a->{$key}{'Group_Rank'}.' force=1');
                    &$sub_log("INFO  \t- TS3 Query        \t- Removed entire Military Rank GroupID: "
                        .$a->{$key}{'Group_Rank'});
                    delete $Features_ref->{'Rank'.$rank};
                }
                else {
                    &$sub_send( 'servergroupdelclient sgid='
                        .$a->{$key}{'Group_Rank'}.' cldbid='.$DBID );
                    &$sub_log("INFO  \t- TS3 Query        \t- ".$a->{$key}{'Nickname'}
                        .' Removed from Military Rank GroupID: '.$a->{$key}{'Group_Rank'});
                }
                sleep 0.01;
            }
            if (exists $a->{$key}{'Group_Trace'}) {
                my $hops = $FFClients_ref->{$DBID}{'Hops'};
                if ( defined $hops ) {
                    $hops = 1 if $hops < 1;
                    --$Features_ref->{'TraceRoute'}{$hops};
                    if ($Features_ref->{'TraceRoute'}{$hops} < 1) {
                        &$sub_send('servergroupdel sgid='.$a->{$key}{'Group_Trace'}.' force=1');
                        &$sub_log("INFO  \t- TS3 Query        \t- Removed entire Traceroute GroupID: "
                            .$a->{$key}{'Group_Trace'});
                        delete $Features_ref->{'TraceRoute'}{$hops};
                        delete $Features_ref->{'TraceRoute'}{'GroupID'.$hops};
                    }
                    else {
                        &$sub_send('servergroupdelclient sgid='
                            .$a->{$key}{'Group_Trace'}.' cldbid='.$DBID);
                        &$sub_log("INFO  \t- TS3 Query        \t- "
                            .$a->{$key}{'Nickname'}.' removed from Traceroute GroupID: '
                            .$a->{$key}{'Group_Trace'});
                    }
                }
                sleep 0.01;
            }
            if (exists $a->{$key}{'Group_Status'}) {
                &$sub_send( 'servergroupdel sgid='.$a->{$key}{'Group_Status'}.' force=1' );
                &$sub_log("INFO  \t- TS3 Query        \t- "
                    .$a->{$key}{'Nickname'}.' removed from Status GroupID: '
                    .$a->{$key}{'Group_Status'});
            }
            if (exists $a->{$key}{'Group_Fill'}) {
                my $used = $a->{$key}{'Group_Fill_Used'};
                --$Features_ref->{'Fill-'.$used}{'Users'};
                if ($Features_ref->{'Fill-'.$used}{'Users'} < 1) {
                    &$sub_send('servergroupdel sgid='.$a->{$key}{'Group_Fill'}.' force=1');
                    &$sub_log("INFO  \t- TS3 Query        \t- Removed entire AutoFill GroupID: "
                        .$a->{$key}{'Group_Fill'});
                    delete $Features_ref->{'Fill-'.$used};
                }
                else {
                    &$sub_send( 'servergroupdelclient sgid='
                        .$a->{$key}{'Group_Fill'}.' cldbid='.$DBID );
                    &$sub_log("INFO  \t- TS3 Query        \t- "
                        .$a->{$key}{'Nickname'}.' removed from AutoFill GroupID: '
                        .$a->{$key}{'Group_Fill'});
                }
                sleep 0.01;
            }
            if (exists $a->{$key}{'Group_Ping'}) {
                &$sub_send( 'servergroupdel sgid='.$a->{$key}{'Group_Ping'}.' force=1' );
                &$sub_log("INFO  \t- TS3 Query        \t- ".$a->{$key}{'Nickname'}.' removed from Ping GroupID: '.$a->{$key}{'Group_Ping'});
                sleep 0.01;
            }
            if (exists $a->{$key}{'ChanPunished'}) {
                &$sub_send( 'servergroupdelclient sgid='.$groups_ref->{'Group_Sticky'}.' cldbid='.$a->{$key}{'DBID'} );
                &$sub_log("INFO  \t- TS3 Query        \t- "
                    .$a->{$key}{'Nickname'}.' removed from Sticky GroupID: '
                    .$groups_ref->{'Group_Sticky'}) if exists $a->{$key}{'Nickname'};
                sleep 0.01;
            }
        }
    }
    my $Removed;
#   Cleanup Online Hash
    foreach $Deletekey (@QueueDelete) {
        if ($a->{$Deletekey}{'Nickname'}) {
            --$TotalClients;
            $TotalClients = 0 if $TotalClients < 0;
            $Removed = 1;
            &$sub_log("INFO  \t- TS3 Query        \t- ".$a->{$Deletekey}{'Nickname'}
                .' disconnected... ONLINE: '.$TotalClients)
        }
        delete $a->{$Deletekey};
    }
    @QueueDelete = ();
    return 1 if $Removed;
}

sub Rbm_MonitorSocket {
    my ($socket,$ChanWatchSock,$num,$settings_ref) = @_;
    $| = 1;
    $SIG{CHLD} = "IGNORE";
    my $Pid = fork();
    if (not defined $Pid) {
        &$sub_log("ERROR \t- Sock2 Thread        \t- Resources not avilable to fork Thread2 process!");
    }
    elsif ($Pid == 0) {
        my ($bytes_read,$Buffer);
        my $SET_WatchOn = $settings_ref->{'Channel_Watch_On'};
        my $file = 'rbm_stored/rbm_query.cf';
        my ($ModID,$QueryDB,$CACHE) = $settings_ref->{'BotCLID'};
        my %stored;
#       Open query cache file for socket 2 only
        unless ($ChanWatchSock) {
            unlink $file;
            open $QueryDB, ">>",$file or die $!;
            flock($QueryDB, 2);
        }
        while ($Buffer = <$socket>) {
            chomp $Buffer;
            if ( $Buffer =~ /msg\=PING target\=\d+ invokerid\=(\d+)/ ) {
                syswrite $socket, 'sendtextmessage targetmode=1 target='.$1.' msg=PONG'.$nl;
            }
            next if $Buffer =~ /msg\=PONG|msg\=PING|$$BotName_ref/;
#           Store departures for main bot
            if (!defined $ChanWatchSock && $Buffer =~ /notifyclientleftview/) {
                $Buffer =~ s/[\n\r]//go;
                open($CACHE, ">>",'rbm_stored/rbm_cache.cf')
                    or die "ERROR\t- Socket".$socket."   \t- Couldn\'t Load rbm_cache.cf: ".$!;
                flock($CACHE, 2);
                syswrite $CACHE, $Buffer.'|';
                flock($CACHE, 8);
                close $CACHE;
            }
            elsif ( defined $ChanWatchSock && $SET_WatchOn eq 1
                && $Buffer =~ /notifytextmessage targetmode\=2 msg\=(\S+) invokerid=(\d+) invokername=(\S+)/ ) {
                &rbm_features::Rbm_ChannelWatch($socket,$1,$2,$3,\%NowPlaying,$settings_ref,$num);
            }

            if ($settings_ref->{'IRC_Bot_On'} ne 0
                && $Buffer !~ /invokerid\=$ModID|target\=$ModID/) {
                open($CACHE, ">>",'rbm_stored/rbm_TS3cache.cf')
                    or die "ERROR\t- Socket".$socket."   \t- Couldn\'t Load rbm_cache.cf: ".$!;
                syswrite $CACHE, 'ts3='.$Buffer.'|';
                close $CACHE;
            }
            unless ($ChanWatchSock) {
                if ($Buffer =~ /clid=(\d+) client_unique_identifier=ServerQuery/o) {
                   $stored{$1}{'Online'} = 1;
                   next;
                }
                elsif ($Buffer =~ /notifyclientleftview cfid=\d+ ctid=\d+ reasonid=\d+ reasonmsg=\S+ clid=(\d+)/o) {
                    if (exists $stored{$1}{'Online'}) {
                        delete $stored{$1}{'Online'};
                        next;
                    }
                }
                $Buffer =~ s/[\r\n]/\<br\>/gi;
                $Buffer =~ s/\<br\>\<br\>/\<br\>/gi;
                syswrite $QueryDB, $Buffer.'<br>'.$nl;
            }
        }
        flock($QueryDB, 8) if $QueryDB;
        close $QueryDB if $QueryDB;
        exit 0;
    }
}

# loop through main socket from main program.
sub Rbm_Watch {
    my $bytes_read = 0;
    my $Buffer = '';
    return if $settings_ref->{'Exclamation_Triggers_On'} eq 0;
    for (1..4) {
        $bytes_read = sysread($sock, $Buffer, 7000*1024);
        if ( defined $bytes_read && $bytes_read != 0 ) {
            $bytes_read =~ s/\s+$//;
            $MODreceived = $MODreceived + $bytes_read;
            &$sub_trigs($Buffer)
                unless $settings_ref->{'Exclamation_Triggers_On'} eq 0;
        }
        else {
            return;
        }
        sleep 0.003;
    }
}

sub Rbm_PartMsgs {
    my $settings = shift;
    return if $settings->{'Verbose_Global_Onpart_Random_Goodbye'} eq 0;
    my ($msg,$key,@deletemsgs,$ran_number,$HexCodes_ref,$AlterMsg,$tmp,$DBID,
        $length,$Location,$range,@chars,@array,$chr);
    foreach $key (keys %PartMsgs) {
        $msg = $PartMsgs{$key}{'Msg'};
        next if $PartMsgs{$key}{'Time'} > time - 2;
        $HexCodes_ref = &Rbm_HexColors;
        $ran_number = rand( 1107 - length($msg) );
        $ran_number = sprintf("%.0f", $ran_number);
        $length = length($msg);
        $Location = $HexCodes_ref->[$ran_number - $length];
        $range = sprintf("%.0f", $length / 35);
        $range = 1 if $range == 0;
        @chars = map substr($msg, $_, $range), 0..($length - 1);
        $msg =~ s/\\s/\|/gi;
        @array = unpack "(A$range)*", $msg;
        foreach $chr (@array) {
            $chr =~ s/^(.*?)$/\[COLOR\=\#$Location\]$1\[\/COLOR\]/;
            $AlterMsg .= $chr;
            $Location = $HexCodes_ref->[$ran_number];
            ++$ran_number;
        }
        $AlterMsg =~ s/\|/\\s/gi;
        &$sub_send('sendtextmessage targetmode=3 target=1 msg='.$AlterMsg)
            unless @deletemsgs;
        push(@deletemsgs,$key);
    }
    for (@deletemsgs) {
        delete $PartMsgs{$_};
    }
}

# !Trigger system
sub Rbm_Triggers {
    my $Buffer = shift;
    my $BotName_ref = &$sub_cleantext($settings_ref->{'Query_Bot_Name'});
    my $BotName_ref2 = &$sub_cleantext($settings_ref->{'Query_Bot_Name2'});
    my ($online_ref,$target,$cfid,$ctid,$reasonid,$clid,$client_identifier,
        $client_nickname,$targetmode,$msg,$invokerid,$invokername) = (\%online, 3);
    return if $Buffer =~ /PONG/o;
#   Command Flood Monitoring Subroutine
    sub Monitor_cmds {
        my ($invokerid,$online_ref) = @_;
        if (exists $online_ref->{$invokerid}{'CmdFloodBLOCKED'}) {
            &$sub_send('sendtextmessage targetmode=1 target='.$invokerid
                .' msg=[COLOR=BLUE]Please\sslow\sdown\,\sand\smaybe\sI\'ll\shelp\syou.[/COLOR]');
            return 1;
        }
        if (!exists $online_ref->{$invokerid}{'CmdFlood'}) {
            $online_ref->{$invokerid}{'CmdFlood'} = time;
        }
        else {
            my $existing = $online_ref->{$invokerid}{'CmdFlood'};
            $online_ref->{$invokerid}{'CmdFlood'} = $existing .','. time;
        }
        return undef;
    }
    if ($Buffer =~ /notifytextmessage/o) {
        ($targetmode,$msg,$invokerid,$invokername) = $Buffer =~
            /targetmode=(\d+) msg=(\S+).*?invokerid=(\d+) invokername=(\S+)/o;
#       Command Flood Monitoring
        return unless defined $invokerid;
        return if defined $invokerid && exists $settings_ref->{'BotCLID'}
            && $invokerid == $settings_ref->{'BotCLID'};
        my $result = &Monitor_cmds($invokerid,$online_ref);
        return if $result;
        $target = $invokerid if $targetmode == 1;
    }
    return unless $msg;
    $msg = &$sub_cleantext($msg,1);
    if ($$msg =~ /^(\!\S+.*?)$/o) {
        &$sub_log("INFO  \t- Triggers    \t\t- "
        .$online_ref->{$invokerid}{'Nickname'}.' issued trigger command '.$1);
    }
    if ($$msg =~ /^\!help/oi) {
        $gameicons_ref = &rbm_features::Rbm_Trig_Help( $invokerid,$invokername,
            $BotName_ref,$settings_ref,$gameicons_ref,$$msg );
    }
    elsif ($$msg =~ /^\!irc\\s(\S+)$/oi) { # IRC Interaction.
        my $result = &$sub_cleantext($1, 1);
        my $Allowed = &Rbm_check_admin_status($invokerid,$settings_ref,
            'Exclamation_Triggers_Admin_Group_IDs');
        if ($Allowed) {
            open(my $CACHE, ">>",'rbm_stored/rbm_irc_cache.cf');
            syswrite $CACHE, 'DBID='.$online_ref->{$invokerid}{'DBID'}
            .' CLID='.$invokerid.' IRC='.$$result.'|';
            close $CACHE;
        }
    }
    elsif ($$msg =~ /^\!seenlast\\s(\d+)$/oi) { # Last <range> of clients seen online.
        my $range = &$sub_cleantext($1, 1);
        my $FFClients_ref = \%FFClients;
        my ($cnt,$time,$ap,$day,$date,$timestamp) = 0;
        foreach my $key (sort { ($FFClients_ref->{$b}{'LastOnline'} || 0)
            <=> ($FFClients_ref->{$a}{'LastOnline'} || 0) } keys %$FFClients_ref) {
            next unless $FFClients_ref->{$key}{'Nickname'};
            ++$cnt;
            ($time,$ap,$day,$date) = &$sub_proctime( $FFClients_ref->{$key}{'LastOnline'} );
            $timestamp = &$sub_logformat(join('',($$time.'\s'.$$ap.'\s'.$$day.$$date)), 1);
            &$sub_send('sendtextmessage targetmode='.$targetmode.' target='
                .$target.' msg=[B][COLOR=BLUE]'.$FFClients_ref->{$key}{'Nickname'}
                .'[/COLOR][/B]\slast\sseen\s@\s[B]'.$$timestamp.'[/B]');
            last if $cnt >= ($$range || 25);
        }
    }
    elsif ($$msg =~ /^\!info\\s(\S+)$/oi) { # Client Information stored in RbMods memory.
        my $user = &$sub_cleantext($1, 1);
        my $Allowed = &Rbm_check_admin_status($invokerid,$settings_ref,
            'Exclamation_Triggers_Admin_Group_IDs');
        if ($Allowed) {
            my $results_ref = &$sub_query('clientfind pattern='.$$user);
            my ($CLID) = $$results_ref =~ /clid=(\d+)/ if $results_ref;
            my $found;
            if ($CLID) {
                my $DBID = $online_ref->{$CLID}{'DBID'};
                for my $k1 (keys %$online_ref) {
                    next unless $online_ref->{$k1}{'DBID'} == $DBID;
                    &$sub_send('sendtextmessage targetmode='.$targetmode.' target='.$target
                        .' msg=[COLOR=BLUE][B]'.$online_ref->{$CLID}{'Nickname'}
                        .'[/B]\'s\sInformation:[/COLOR]');
                    for my $k2 (sort keys %{$online_ref->{ $k1 }}) {
                        next unless $k2 and exists $online_ref->{$k1}{$k2};
                        &$sub_send('sendtextmessage targetmode='.$targetmode.' target='.$target
                            .' msg=[COLOR=RED][B]'.$k2.'[/B][/COLOR]\s[COLOR=BLACK]'
                            .$online_ref->{$k1}{$k2}.'[/COLOR]');
                    }
                    $found = 1;
                    last;
                }
            }
            unless ($found) {
                &$sub_send('sendtextmessage targetmode='.$targetmode.' target='.$target
                    .' msg=[COLOR=RED]Couldn\'t find a match for[/COLOR][B][COLOR=BLUE]'
                    .$user.'[/COLOR][B][COLOR=RED]![/COLOR]');
            }
        }
    }
    elsif ($$msg =~ /^\!mkick\\s\S+$/oi) { # IRC Interaction
        my $cleaned = &$sub_cleantext($$msg, 1);
        my $Allowed = &Rbm_check_admin_status($invokerid,$settings_ref,
            'Exclamation_Triggers_Admin_Group_IDs');
        if ($Allowed) {
            my $DefaultMsg = 'Someone\sdoesn\'t\slike\syou.';
            if ($$cleaned =~ /name\\s([\']?\S+[\']?)(\\s[\S]+$)?/io) {
                my ($enemyName,$msg,$key) = ($1,$2);
                foreach $key (keys %$online_ref) {
                    if (exists $online_ref->{$key}{'Nickname'}
                        && $online_ref->{$key}{'Nickname'} =~ /^$enemyName$/i) {
                        &$sub_send( 'clientkick clid='.$key.' reasonid=5 reasonmsg='.$DefaultMsg);
                    }
                }
            }
            if ($$cleaned =~ /ccode\\s(\w+)(\\s[\S]+$)?/io) {
                my ($enemyCCode,$msg,$key) = ($1,$2);
                foreach $key (keys %$online_ref) {
                    if (exists $online_ref->{$key}{'CCode'}
                        && $online_ref->{$key}{'CCode'} eq uc($enemyCCode)) {
                        if ($msg) {
                            $msg =~ s/^\\s//o;
                            $DefaultMsg = $msg;
                        }
                        &$sub_send( 'clientkick clid='.$key.' reasonid=5 reasonmsg='.$DefaultMsg);
                    }
                }
            }
        }
    }
    elsif ($$msg =~ /^\!(ChanClean|ChannelClean|Clean)/oi) {
        my $Allowed = &Rbm_check_admin_status($invokerid,$settings_ref,
            'Exclamation_Triggers_Admin_Group_IDs');
        if ($Allowed) {
            $settings_ref->{'Channel_Delete_Dormant_Requirements_saved'}
                = $settings_ref->{'Channel_Delete_Dormant_Requirements'};
            $settings_ref->{'Channel_Delete_Dormant_Requirements_Interval_saved'}
                = $settings_ref->{'Channel_Delete_Dormant_Interval'};
            $settings_ref->{'Channel_Delete_Dormant_Requirements'} = 1;
            $settings_ref->{'Channel_Delete_Dormant_Interval'} = 3;
            $settings_ref->{'Channel_Delete_Dormant_Requirements_triggered'} = 9;
            my $channellist_ref = &$sub_query('channellist',
                'pid=\d+ channel_order=\d+.*?error id=0 msg=ok');
            &$sub_chdel(\%online,\%rooms,$settings_ref,$FFChans,$channellist_ref);
        }
    }
    elsif ($$msg =~ /^\!amove/oi) {
        my $Allowed = &Rbm_check_admin_status($invokerid,$settings_ref,
            'Exclamation_Triggers_Admin_Group_IDs');
        if ($Allowed) {
            my ($TCLID,$TCCODE);
            foreach $TCLID (keys %$online_ref) {
                $TCCODE = $online_ref->{$TCLID}{'CCode'} || $online_ref->{$TCLID}{'CCode2'};
                unless ($online_ref->{$TCLID}{'IP'} =~ /^(127\.|192\.168|1\.1\.1|10\.)|^172\.(\d+)/o
                    and (!$2 or $2 < 16 or $2 > 31) ) {

                    &$sub_automove($TCLID,\%online,$settings_ref,\%FFClients,
                        $channellist_ref,\%rooms,$TCCODE,undef,1);
                }
                else {
                    &$sub_automove($TCLID,\%online,$settings_ref,\%FFClients,
                        $channellist_ref,\%rooms);
                }
            }
        }
    }
    elsif ($$msg =~ /^\!seen\\s\#(\S+)/oi) {
        my $result = &$sub_cleantext($1, 1);
        &rbm_features::Rbm_LastSeen(undef,$invokerid,$settings_ref,\%online,\%FFClients,
            \%rooms,$target,undef,$targetmode,$$result);
    }
    elsif ($$msg =~ /^\!seen\\s(\S+)/oi) {
        my $result = &$sub_cleantext($1, 1);
        &rbm_features::Rbm_LastSeen($$result,$invokerid,$settings_ref,\%online,\%FFClients,
            \%rooms,$target,undef,$targetmode);
    }
    elsif ($$msg =~ /^\!tag[line]?\\s(\S+)/oi) {
        my $result = &$sub_cleantext($1, 1);
        my $TagLine = substr($$result,0,199);
        my $badword;
        &$sub_log("INFO  \t- TagLine    \t\t- Checking ".$TagLine.' against word list...');
        $TagLine =~ s/\\s/ /gi;
        foreach $badword (@$badwords_ref) {
            $badword =~ s/ /\\s/gi;
            if ($TagLine =~ /$badword/i) {
                $TagLine =~ s/$badword//gi;
            }
        }
        $TagLine =~ s/ /\\s/gi;
        &$sub_send( 'sendtextmessage targetmode=1 target='.$invokerid
            .' msg=[COLOR=BLUE]New\sTagLine:[/COLOR]\s[COLOR=RED][I]'.$TagLine
            .'[/I][/COLOR]\s([B]'.length($TagLine).'[/B]/[B]200[/B])' );
        $online_ref->{$invokerid}{'TagLine'} = $TagLine;
    }
    elsif ($$msg =~ /^\!deltag/oi) {
        my $DBID = $online_ref->{$invokerid}{'DBID'};
        my $TagLine = $online_ref->{$invokerid}{'TagLine'} || $FFClients{$DBID}{'TagLine'};
        return unless $TagLine;
        &$sub_send( 'sendtextmessage targetmode=1 target='.$invokerid
            .' msg=[COLOR=BLUE]Removed\sTagLine:[/COLOR]\s[COLOR=RED][I]'.$online_ref->{$invokerid}{'TagLine'}
            .'[/I][/COLOR]\s([B]'.length($online_ref->{$invokerid}{'TagLine'}).'[/B]/[B]150[/B])' );
        delete $online_ref->{$invokerid}{'TagLine'};
        delete $FFClients{$DBID}{'TagLine'};
    }
    elsif ($$msg =~ /^\!purge\\s(\S+)/oi) {
        my $result = &$sub_cleantext($1, 1);
        my $Allowed = &Rbm_check_admin_status($invokerid,$settings_ref,
            'Exclamation_Triggers_Admin_Group_IDs');
        if ($Allowed) {
            &rbm_features::Rbm_LastSeen($$result,$invokerid,$settings_ref,\%online,\%FFClients,
                \%rooms,$target,1,$targetmode);
        }
    }
    elsif ($$msg =~ /^\!purgematch\\s(\S+)/oi) {
        my $result = &$sub_cleantext($1,1);
        my $Allowed = &Rbm_check_admin_status($invokerid,$settings_ref,
            'Exclamation_Triggers_Admin_Group_IDs');
        if ($Allowed) {
            &rbm_features::Rbm_LastSeen($$result,$invokerid,$settings_ref,\%online,\%FFClients,
                \%rooms,$target,2,$targetmode);
        }
    }
    elsif ($$msg =~ /^\!use\\s(\S+)/oi) {
        my $result = &$sub_cleantext($1, 1);
        $gameicons_ref = &$sub_NowPlaying($$result,$invokerid,$settings_ref,
            $gameicons_ref,\%online,\%NowPlaying,'Stop','Go');
    }
    elsif ($$msg =~ /^\!(stop|notplay|playstop|unuse)/oi) {
        $gameicons_ref = &$sub_NowPlaying(undef,$invokerid,$settings_ref,
            $gameicons_ref,\%online,\%NowPlaying,'Stop');
    }
    elsif ($$msg =~ /^\!Quote/oi) {
        my $RandQuote = &rbm_features::Rbm_RandomArrayElement(@$quotes_ref);
        my $Quote = &$sub_cleantext( join(' ',@$RandQuote) );
        &$sub_send('sendtextmessage targetmode='.$targetmode.' target='.$target
            .' msg=[COLOR=BLUE][I]'.$$Quote.'[/I][/COLOR]'.$nl);
    }
    elsif ( $$msg =~ /^\!Word/oi ) {
        my $random = &rbm_features::Rbm_RandomHashKey($randomwords_ref);
        my $Line = $randomwords_ref->{$random};
        my $Meaning = &$sub_cleantext($Line);
        $random = &$sub_cleantext($random);
        $$random = ucfirst($$random);
        $$Meaning =~ s/\|\\s/\\s\\-\\s/gi;
        &$sub_send('sendtextmessage targetmode='.$targetmode.' target='
            .$target.' msg=[COLOR=RED][B]'.$$random.'[/B][/COLOR]:\s'.$$Meaning.$nl);
    }
    elsif ($$msg =~ /\Q$$BotName_ref\E/oi) {
        my $RandResponse_ref = &rbm_features::Rbm_RandomArrayElement(@$q_responses_ref);
        my $RandomMsg = &$sub_cleantext(join(' ',@$RandResponse_ref));
        return unless $RandomMsg;
        &$sub_send('sendtextmessage targetmode=3 target=1 msg='.$$RandomMsg.$nl);
    }
    else {
#       RbMod - Check clients exemptions
        my $Exempt = &$sub_exempt($invokerid,
            $settings_ref->{'All_Language_Filters_Exempt_Group_IDs'});
        if ( exists $settings_ref->{'BotCLID'} && $invokerid && !$Exempt
            && $settings_ref->{'BotCLID'} != $invokerid
            && $BOTCLIDs[1] && $BOTCLIDs[1] != $invokerid ) {
#           Language Filter - Global / Private Chat
            my $badword;
            foreach $badword (@$badwords_ref) {
                $$msg =~ s/\\s/ /gi;
                if ($$msg =~ /\Q$badword\E/i) {
                    &$sub_log( "INFO  \t- Chat Language    \t- Kicking "
                        .$invokername.' for inappropriate language: '.$badword);
                    &$sub_send( 'clientkick clid='.$invokerid
                        .' reasonid=5 reasonmsg=Please\sdon\'t\sswear\!\n');
                    return;
                }
            }
        }
        return unless $Buffer =~ /notifytextmessage targetmode=1/;
#       Safe to respond with a random bot message now.
        my $RandResponse_ref = &rbm_features::Rbm_RandomArrayElement(@$q_responses_ref);
        my $RandomMsg = &$sub_cleantext( join(' ',@$RandResponse_ref) );
        $$RandomMsg = 'Please\sdon\'t\sswear\!' unless $RandomMsg;
        &$sub_send( 'sendtextmessage targetmode=1 target='.$invokerid.' msg='.$$RandomMsg.$nl );
    }
}


sub Rbm_RemoteControl_Host {
    $| = 1;
#   $SIG{CHLD} = "IGNORE";
    my $Pid = fork();
    if (not defined $Pid) {
        &$sub_log("ERROR \t- Sock2 Thread        \t- Resources not avilable to fork Thread2 process!");
    }
    elsif ($Pid == 0) {
        my $rc_sock = new IO::Socket::INET (LocalHost => '0.0.0.0',
                                            LocalPort => 9002,
                                            Listen    => 5,
                                            Proto     => 'tcp',
                                            Reuse     => 1,
                                            blocking  => 0,
                                           );
        die "Socket could not be created. Reason: $!\n" unless ($rc_sock);
      #  $rc_sock->autoflush(1);
        my $readable_handles = new IO::Select();
        $readable_handles->add($rc_sock);
        my $settings_loaded;

        while (1) {
            # select() blocks until a socket is ready to be read or written
            my ($new_readable)
                    = IO::Select->select($readable_handles, undef, undef, 0.5);

            # Server RECEIVE
            foreach my $mng_sock (@$new_readable) {
                if ($mng_sock == $rc_sock) {
                    my $new_sock = $mng_sock->accept();
                    $readable_handles->add($new_sock);
                    say 'New client connection.';
                    say 'Open sockets = '.scalar(@$new_readable);
                }
                else {
                    # Client socket, ready for reading.
                    my $Address = $mng_sock->peerhost();
                    my $Port    = $mng_sock->peerport();
                    say "Data detected from ".$Address.':'.$Port;
                    my $buf = <$mng_sock>;
                    if ($buf) { # .... Do stuff with $buf
                        say $buf;
                        if ($buf =~ /^Quit/o) {
                            print $Address.':'.$Port.' Program Disconnection'.$nl;
                            say 'Open sockets = '.(scalar(@$new_readable) - 1);
                            # Tell client to hangup
                            syswrite $mng_sock, 'Disconnect Client Socket'.$nl;
                            # Cleanup
                            $readable_handles->remove($mng_sock);
                            close($mng_sock);
                            $settings_loaded = undef;
                        }
                    }
                    else { # Client closed socket.
                        print $Address.':'.$Port.' User Disconnection'.$nl;
                        $readable_handles->remove($sock);
                        close($sock) if $sock;
                        say 'Open sockets = '.(scalar(@$new_readable) - 1);
                        $settings_loaded = undef;
                    }
                }
            }

            # Server SEND
            my @ready = $readable_handles->can_write(2);
            foreach my $mng_sock (@ready) {
                say 'Data stream still established';
                syswrite $mng_sock, 'Data stream still established'.$nl;
                unless ( $settings_loaded ) {
                    $settings_loaded = 1;
                    my $key;
                    foreach $key (keys %$settings_ref) {
                        syswrite $mng_sock, $key.' = '.$settings_ref->{$key}.$nl;
                        sleep 0.01;
                    }
                    my $variablecount = keys %$settings_ref;
                    syswrite $mng_sock, 'Total = '.$variablecount.$nl;
                }
            }
        }
        exit 0;
    }
}

sub Rbm_WebServer {
    my $websock = shift;
    my $SET_WebAddr = $settings_ref->{'WebServer_Address'};
    my $SET_WebPort = $settings_ref->{'WebServer_Port'};
    my $SET_WebMax = $settings_ref->{'WebServer_Client_Limit'};
    my $SET_WebAllow = $settings_ref->{'WebServer_Client_WhiteList'};
    my @WhiteListed = split /\,/, $SET_WebAllow;
    $| = 1;
    $SIG{CHLD} = "IGNORE";
    my $Pid2 = fork();
    if (!defined $Pid2) {
        &$sub_log("ERROR \t- WebServerThread        \t- Resources not avilable to fork server process!");
    }
    elsif ($Pid2 == 0) {
        my ($read,$request,$Proceed,$Client_Address,$Client_Port,$cookie,$File,
            $f,$client,$tempclient,$sel2,@socks,$IP);
        my $cached = '';
        my $excess = '';
        my $Header = "HTTP/1.0 200 OK\nContent-Type: text/html;charset=UTF-8\n\n";
#        &$sub_log("INFO \t- WebServer       \t- Starting Web Server on ".$SET_WebAddr.':'.$SET_WebPort);

        my $server = IO::Socket::INET->new( Proto     => 'tcp',
                                            LocalAddr => $SET_WebAddr,
                                            LocalPort => $SET_WebPort,
                                            Listen    => $SET_WebMax,
                                            type      => 'sock_str',
                                            ReuseAddr => 1,
                                            Blocking  => 1,
        ) or die and &$sub_log("ERROR \t- WebServer          \t- Couldn\'t bind to ".$SET_WebAddr.':'.$SET_WebPort.'!');

        if ( defined $server ) {
            &$sub_log("INFO  \t- WebServer       \t- Listening for ".$SET_WebMax." max connections at http\:\/\/$SET_WebAddr\:$SET_WebPort\/");
        }
        else {
            &$sub_log("ERROR \t- WebServer          \t- Couldn\'t bind to ".$SET_WebAddr.':'.$SET_WebPort.'!');
            &$sub_log("ERROR \t- WebServer          \t- TIPS: Check for zombie processes or the web address in rbm_settings.cf...");
            &Rbm_Cleanup();
        }
        require rbm_website;
        $server->autoflush(1);
#       Listen for connections
        while ( my $tempclient = $server->accept() ) {
            $sel2 = new IO::Select($tempclient);
            if (@socks = $sel2->can_read(3)) {
                $client = shift(@socks);
                $read = sysread($client, $request, 56*1024);
                if ( $read && $read != 0) {
                    $Client_Address = $client->peerhost();
                    $Client_Port    = $client->peerport();
#                    say $request;
                    if ($request !~ /\n/) {
                        close $tempclient;
                        close $client;
                        next;
                    }
                    $request =~ s`[\r\n]``gi;

                    if ($request =~ /SPLITEND/i && $request !~ /SPLITENDALL/i) {
                        ($excess) = $request =~ /SPLITEND(.*?)$/i;
                        if ( $cached eq '' ) {
                            ($request) = $request =~ m/^(.*?)\%20SPLITEND/i;
                        }
                        else {
                            ($request) = $request =~ m/SPLITBEGIN\%20(.*?)\%20SPLITEND/i;
                            $request = $request;
                        }
                        $request = '' unless $request;
                        $request =~ s/^\%20//gi;
                        $request =~ s/\%20$//gi;
                        $cached = $cached.$request;
                        close $client;
                        sleep 0.003;
                        next;
                    }
                    unless ($Client_Address) {
                        close $client;
                        sleep 0.003;
                        next;
                    }
                    if ( length($cached) > 1 ) {
                        $request = $cached.$excess;
                        $cached = '';
                        $excess = '';
                    }
                    $request =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
#                   &$sub_log("INFO \t- WebServer       \t- " .$request.' request from '.$Client_Address.':'.$Client_Port);
                    foreach $IP ( @WhiteListed ) {
                        if ( $Client_Address && $Client_Address eq $IP ) {
                            $Proceed = 1;
                            last;
                        }
                    }
                    if ( !$Proceed ) {
                        &$sub_log("WARN \t- WebServer       \t- Denied " .$request.' request from '.$Client_Address.':'.$Client_Port.'!');
                    }
                    elsif ($request) {
#                         Control-Panel
                        if ( $request =~ m`^GET / [\s\S]+Cookie\: RbMod\=(\S+)` ) {
                            $cookie = $1;
                            syswrite $client, $Header;
                            &rbm_website::Rbm_AccessCookie($client,$cookie);
                            &rbm_website::Rbm_Launch($client,$1,$settings_ref);
                        }
#                         Splash
                        elsif ( $request =~ m`^GET /(\S+[^\.\S+])? HTTP/1.[01]` ) {
                            syswrite $client, $Header;
                            &rbm_website::Rbm_Login($client,$1);
                        }
#                         Login CLICK
                        elsif ( $request =~ m`\/Login\?(name\=\S+\&pass\=\S+)` ) {
                            syswrite $client, $Header;
                            &rbm_website::Rbm_LoginProcess($client,$1,$settings_ref);
                        }
#                         Logout CLICK
                        elsif ( $request =~ m`\/Logout .*?Cookie\: RbMod\=(\S+)` ) {
                            syswrite $client, $Header;
                            &rbm_website::Rbm_DeleteCookie($1);
                            &rbm_website::Rbm_Redirect($client,$1);
                        }
#                         Settings Page
                        elsif ( $request =~ m`\/settings .*?Cookie\: RbMod\=(\S+)` ) {
                            syswrite $client, $Header;
                            &rbm_website::Rbm_AccessCookie($client,$1);
                            &rbm_website::Rbm_Settings($client);
                        }
#                         Settings Edit
                        elsif ( $request =~ m`\/FormSettings\?.*?Cookie\: RbMod\=(\S+)` ) {
                            syswrite $client, $Header;
                            &rbm_website::Rbm_AccessCookie($client,$1);
                            &rbm_website::Rbm_SaveSettings($request);
                        }
#                         MOTD Edit
                        elsif ( $request =~ m`EditMOTD\=[\s\S]+&=Save&=Reset&[\s\S]+Cookie\: RbMod\=(\S+)`i ) {
                            syswrite $client, $Header;
                            &rbm_website::Rbm_AccessCookie($client,$1);
                            &rbm_website::Rbm_SaveMOTD($request);
                        }
#                         MOTD Page
                        elsif ( $request =~ m`/motd .*?Cookie\: RbMod\=(\S+)` ) {
                            syswrite $client, $Header;
                            &rbm_website::Rbm_AccessCookie($client,$1);
                            &rbm_website::Rbm_MOTD($client,$request);
                        }
#                         Database Page
                        elsif ( $request =~ m`\/db.*?Cookie\: RbMod\=(\S+)` ) {
                            syswrite $client, $Header;
                            &rbm_website::Rbm_AccessCookie($client,$1);
                            &rbm_website::Rbm_ClientDB($client,$request);
                        }
#                         Database Page
                        elsif ( $request =~ m`\/DBTable\? .*?Cookie\: RbMod\=(\S+)` ) {
                            syswrite $client, $Header;
                            &rbm_website::Rbm_AccessCookie($client,$1);
                            &rbm_website::Rbm_ClientDBEdit($client,$request);
                        }
#                         Logs Page
                        elsif ( $request =~ m`\/logs .+?Cookie\: RbMod\=(\S+)` ) {
                            syswrite $client, $Header;
                            &rbm_website::Rbm_AccessCookie($client,$1);
                            &rbm_website::Rbm_logs($client,$request);
                        }
#                         Logs Load
                        elsif ( $request =~ m`\/logs/?(\S+\.log).+?Cookie\: RbMod\=(\S+)` ) {
                            syswrite $client, $Header;
                            &rbm_website::Rbm_AccessCookie($client,$2);
                            &rbm_website::Rbm_loadlogs($client,$1);
                        }
#                         Query Page
                        elsif ( $request =~ m`\/query .+?Cookie\: RbMod\=(\S+)` ) {
                            syswrite $client, $Header;
                            &rbm_website::Rbm_AccessCookie($client,$1);
                            &rbm_website::Rbm_Query($client,$request);
                        }
#                         Query Data
                        elsif ( $request =~ m`\/querydata.+?Cookie\: RbMod\=(\S+)` ) {
                            syswrite $client, $Header;
                            &rbm_website::Rbm_AccessCookie($client,$1);
                            &rbm_website::Rbm_Querydata($client,$request);
                        }
#                         Query Post
                        elsif ( $request =~ m`\/querypost\?Key\=(.*?)ENDLINE.*?Cookie\: RbMod\=(\S+)`i ) {
                            syswrite $client, $Header;
                            &rbm_website::Rbm_AccessCookie($client,$2);
                            &rbm_website::Rbm_QueryPost($client,$1,$websock);
                        }
#                         Grid1 Controls
                        elsif ( $request =~ m`\/FormGrid1\?.+?Cookie\: RbMod\=(\S+)` ) {
                            syswrite $client, $Header;
                            &rbm_website::Rbm_AccessCookie($client,$1);
                            &rbm_website::Rbm_Grid1($request);
                        }
#                         Misc. Files
                        elsif ( $request =~ m`\/(.+?) HTTP/1.[01]` ) {
                            $File = $1;
                            if (-e $File) {
                                if ( $request =~ m`/(\S+\.[jpeg|jpg])` ) {
                                    print $client "HTTP/1.0 200 OK\nContent-Type: image/jpeg\n\n";
                                }
                                elsif ( $request =~ m`/(\S+\.png)` ) {
                                    print $client "HTTP/1.0 200 OK\nContent-Type: image/png\n\n";
                                }
                                elsif ( $request =~ m`/(\S+\.gif)` ) {
                                    print $client "HTTP/1.0 200 OK\nContent-Type: image/gif\n\n";
                                }
                                else {
                                    close $tempclient;
                                    next;
                                }
                                open($f, "<$File") or die 'No Image! '.$!;
                                binmode $f;
                                while( <$f> ) {
                                    syswrite $client, $_;
                                }
                                syswrite $client, "\r\n\n";
                                close $f;
                            }
                            else {
                                print $client "HTTP/1.0 404 FILE NOT FOUND\n\n";
                                print $client "Content-Type: text/plain;charset=UTF-8\n\n";
                                print $client "File $File not found\n\n";
                            }
                        }
                        else {
                            print $client "HTTP/1.0 400 BAD REQUEST\n\n";
                            print $client "Content-Type: text/plain;charset=UTF-8\n\n";
                            print $client "BAD REQUEST\n\n";
                        }
                    }
                }
                close $client;
            }
            else {
                close $tempclient;
            }
        }
        exit 0;
    }
}

sub Rbm_Sock {
    my $num = shift;
    my $BotName = &$sub_cleantext($settings_ref->{'Query_Bot_Name2'});
    $$BotName = $$BotName.'\s('.$num.')';
    my $Login = $settings_ref->{'Query_Login'};
    my $Address = $settings_ref->{'Query_Address'};
    my $Password = $settings_ref->{'Query_Password'};
    my $Queryport = $settings_ref->{'Query_Port'};
    my $Virtport = $settings_ref->{'Query_Virtual_Server_Port'};
    my $WatchCHID = $settings_ref->{'Channel_Watch_Channel_IDs'};
    my $websock = IO::Socket::INET->new(
        PeerAddr => $Address,
        PeerPort => $Queryport,
        Proto => 'TCP',
        Keepalive => 1,
        Timeout => 30,
        Blocking  => 1,
    ) or &$sub_log("WARN \t- Socket ".$num."         \t- TCP socket failed to start: ".$!, 1) && Rbm_Cleanup;
    $websock->autoflush(1);
    syswrite $websock, 'login '.$Login.' '.$Password.$nl;
    syswrite $websock, 'use port='.$Virtport.$nl;
    syswrite $websock, 'clientupdate client_nickname='.substr($$BotName,0,29).$nl;
    syswrite $websock, 'servernotifyregister event=server'.$nl;
    syswrite $websock, 'servernotifyregister event=textserver'.$nl;
    syswrite $websock, 'servernotifyregister event=textchannel'.$nl;
    syswrite $websock, 'servernotifyregister event=textprivate'.$nl;
    unless (defined $QuiteBoot) {
        syswrite $websock, 'sendtextmessage targetmode=3 target=1 msg=[COLOR=BLUE][B]Started.[/B][/COLOR]'.$nl;
    }
    sleep 0.1;
#   WHOAMI
    my ($BotCLID, $BotCHID, $BotDBID, $return);
    syswrite $websock, 'whoami'.$nl;
    while ( $return = <$websock> ) {
        if ( $return =~ /virtualserver_port=\d+ client_id=(\d+) client_channel_id=(\d+).*?database_id=(\d+)/ ) {
            ($BotCLID, $BotCHID, $BotDBID) = $return =~ /virtualserver_port=\d+ client_id=(\d+) client_channel_id=(\d+).*?database_id=(\d+)/;
            &$sub_log("INFO \t- Socket".$num."         \t- TCP socket".$num." connected with DBID: ".$BotDBID, 1);
            last;
        }
        else {
#           &$sub_log("WARN \t- Socket".$num."         \t- TCP socket".$num." couldn\'t acquire DBID!", 1);
            syswrite $websock, 'whoami'.$nl;
            next;
        }
    }
    if ($num > 1) {
        $num = $num - 2;
        my (@ChanCount) = split /\,/,$WatchCHID;
        if ($ChanCount[$num]) {
            syswrite $websock, 'clientmove clid='.$BotCLID.' cid='.$ChanCount[$num].$nl if $websock;
        }
    }
    return ($websock,$BotCLID,$BotDBID);
}

sub Rbm_KeepAlive {
    my $BotCLID = shift;
    return unless $BotCLID;
    &$sub_send( 'sendtextmessage targetmode=1 target='.$BotCLID.' msg=PING' );
}

sub Rbm_HexColors {
    my @Codes = (
        '000000', '000033', '000080', '00008B', '00009C', '0000CD', '0000EE',
        '0000FF', '003300', '003EFF', '003F87', '004F00', '00611C', '006400',
        '006633', '00688B', '006B54', '007FFF', '008000', '008080', '00868B',
        '008B00', '008B45', '008B8B', '009900', '0099CC', '009ACD', '00AF33',
        '00B2EE', '00BFFF', '00C5CD', '00C78C', '00C957', '00CD00', '00CD66',
        '00CDCD', '00CED1', '00E5EE', '00EE00', '00EE76', '00EEEE', '00F5FF',
        '00FA9A', '00FF00', '00FF33', '00FF66', '00FF7F', '00FFAA', '00FFCC',
        '00FFFF', '00FFFF', '0147FA', '0198E1', '01C5BB', '0276FD', '030303',
        '03A89E', '050505', '05B8CC', '05E9FF', '05EDFF', '068481', '080808',
        '0A0A0A', '0AC92B', '0BB5FF', '0D0D0D', '0D4F8B', '0E8C3A', '0EBFE9',
        '0F0F0F', '0FDDAF', '104E8B', '108070', '120A8F', '121212', '138F6A',
        '141414', '1464F4', '162252', '171717', '174038', '1874CD', '191970',
        '1A1A1A', '1B3F8B', '1B6453', '1C1C1C', '1C86EE', '1D7CF2', '1DA237',
        '1E90FF', '1F1F1F', '20B2AA', '20BF9F', '212121', '213D30', '215E21',
        '218868', '22316C', '228B22', '23238E', '236B8E', '238E68', '242424',
        '24D330', '262626', '26466D', '27408B', '283A90', '284942', '28AE7B',
        '292421', '292929', '2A8E82', '2B2B2B', '2B4F81', '2C5197', '2C5D3F',
        '2E0854', '2E2E2E', '2E37FE', '2E473B', '2E6444', '2E8B57', '2F2F4F',
        '2F4F2F', '2F4F4F', '2F4F4F', '2FAA96', '302B54', '303030', '3063A5',
        '308014', '31B94D', '3232CC', '3232CD', '324F17', '325C74', '327556',
        '329555', '3299CC', '32CC99', '32CD32', '32CD99', '330000', '3300FF',
        '333333', '3333FF', '337147', '33A1C9', '33A1DE', '33FF33', '344152',
        '34925E', '353F3E', '35586C', '3579DC', '362819', '363636', '36648B',
        '36DBCA', '37BC61', '37FDFC', '380474', '383838', '385E0F', '388E8E',
        '38B0DE', '395D33', '397D02', '39B7CD', '3A3A38', '3A5894', '3A5FCD',
        '3A6629', '3A66A7', '3B3178', '3B3B3B', '3B4990', '3B5323', '3B5E2B',
        '3B6AA0', '3B8471', '3CB371', '3D3D3D', '3D5229', '3D59AB', '3D5B43',
        '3D8B37', '3D9140', '3E6B4F', '3E766D', '3E766D', '3E7A5E', '3EA055',
        '3F602B', '3F6826', '3F9E4D', '404040', '40664D', '40E0D0', '414F12',
        '4169E1', '422C2F', '424242', '42426F', '42526C', '426352', '42647F',
        '426F42', '42C0FB', '435D36', '436EEE', '4372AA', '43CD80', '43D58C',
        '454545', '457371', '458B00', '458B74', '45C3B8', '46523C', '4682B4',
        '473C8B', '474747', '476A34', '483D8B', '484D46', '487153', '4876FF',
        '488214', '48D1CC', '4973AB', '4981CE', '499DF5', '49E20E', '49E9BD',
        '4A4A4A', '4A7023', '4A708B', '4A766E', '4A777A', '4AC948', '4B0082',
        '4BB74C', '4C7064', '4CB7A5', '4CBB17', '4D4D4D', '4D4DFF', '4D6B50',
        '4D6FAC', '4D71A3', '4D7865', '4DBD33', '4E78A0', '4EEE94', '4F2F4F',
        '4F4F2F', '4F4F4F', '4F8E83', '4F94CD', '506987', '50729F', '507786',
        '50A6C2', '517693', '517B58', '5190ED', '525252', '525C65', '526F35',
        '527F76', '528B8B', '53868B', '539DC2', '543948', '54632C', '548B54',
        '54FF9F', '551011', '551033', '55141C', '551A8B', '555555', '556B2F',
        '55AE3A', '567E3A', '575757', '577A3A', '584E56', '586949', '595959',
        '5959AB', '596C56', '5971AD', '597368', '5993E5', '5A6351', '5B59BA',
        '5B90F6', '5B9C64', '5C246E', '5C3317', '5C4033', '5C5C5C', '5CACEE',
        '5D478B', '5D7B93', '5D92B1', '5DFC0A', '5E2605', '5E2612', '5E2D79',
        '5E5E5E', '5EDA9E', '5F755E', '5F9EA0', '5F9F9F', '603311', '607B8B',
        '607C6E', '608341', '60AFFE', '615E3F', '616161', '6183A6', '61B329',
        '629632', '62B1F6', '636363', '636F57', '63AB62', '63B8FF', '63D1F4',
        '646F5E', '6495ED', '65909A', '659D32', '660000', '6600FF', '660198',
        '666666', '6666FF', '668014', '668B8B', '668E86', '66CCCC', '66CD00',
        '66CDAA', '66FF66', '67C8FF', '67E6EC', '68228B', '683A5E', '687C97',
        '687E5A', '68838B', '688571', '691F01', '694489', '6959CD', '696969',
        '696969', '698B22', '698B69', '6996AD', '699864', '6A5ACD', '6A8455',
        '6B238E', '6B4226', '6B6B6B', '6B8E23', '6C7B8B', '6CA6CD', '6D9BF1',
        '6E6E6E', '6E7B8B', '6E8B3D', '6EFF70', '6F4242', '6F7285', '707070',
        '708090', '708090', '7093DB', '70DB93', '70DBDB', '71637D', '7171C6',
        '71C671', '72587F', '733D1A', '734A12', '737373', '739AC5', '73B1B7',
        '748269', '74BBFB', '754C78', '757575', '759B84', '75A1D0', '76EE00',
        '76EEC6', '777733', '778899', '778899', '77896C', '787878', '78A489',
        '78AB46', '79973F', '79A888', '79CDCD', '7A378B', '7A67EE', '7A7A7A',
        '7A8B8B', '7AA9DD', '7AC5CD', '7B3F00', '7B68EE', '7B7922', '7BBF6A',
        '7BCC70', '7CCD7C', '7CFC00', '7D26CD', '7D7D7D', '7D7F94', '7D9EC0',
        '7EB6FF', '7EC0EE', '7F00FF', '7F7F7F', '7F8778', '7F9A65', '7FFF00',
        '7FFFD4', '800000', '800080', '802A2A', '808000', '808069', '808080',
        '808080', '808A87', '816687', '820BBB', '828282', '82CFFD', '836FFF',
        '838B83', '838B8B', '838EDE', '83F52C', '8470FF', '84BE6A', '855E42',
        '856363', '858585', '859C27', '862A51', '86C67C', '871F78', '872657',
        '87421F', '878787', '87CEEB', '87CEFA', '87CEFF', '88ACE0', '8968CD',
        '8A2BE2', '8A3324', '8A360F', '8A8A8A', '8AA37B', '8B0000', '8B008B',
        '8B0A50', '8B1A1A', '8B1C62', '8B2252', '8B2323', '8B2500', '8B3626',
        '8B3A3A', '8B3A62', '8B3E2F', '8B4500', '8B4513', '8B4726', '8B475D',
        '8B4789', '8B4C39', '8B5742', '8B5A00', '8B5A2B', '8B5F65', '8B636C',
        '8B6508', '8B668B', '8B6914', '8B6969', '8B7355', '8B7500', '8B7765',
        '8B795E', '8B7B8B', '8B7D6B', '8B7D7B', '8B7E66', '8B814C', '8B8378',
        '8B8386', '8B864E', '8B8682', '8B8878', '8B8970', '8B8989', '8B8B00',
        '8B8B7A', '8B8B83', '8BA446', '8BA870', '8C1717', '8C7853', '8C8C8C',
        '8CDD81', '8DB6CD', '8DEEEE', '8E2323', '8E236B', '8E388E', '8E6B23',
        '8E8E38', '8EE5EE', '8F5E99', '8F8F8F', '8F8FBC', '8FA880', '8FBC8F',
        '8FD8D8', '90EE90', '90FEFB', '91219E', '912CEE', '919191', '91B49C',
        '92CCA6', '9370DB', '93DB70', '9400D3', '949494', '964514', '969696',
        '96C8A2', '96CDCD', '97694F', '97FFFF', '98A148', '98F5FF', '98FB98',
        '990099', '99182C', '9932CC', '9932CD', '993300', '999999', '99CC32',
        '99CDC9', '9A32CD', '9AC0CD', '9ACD32', '9AFF9A', '9B30FF', '9BC4E2',
        '9BCD9B', '9C661F', '9C6B98', '9C9C9C', '9CA998', '9CBA7F', '9CCB19',
        '9D1309', '9D6B84', '9D8851', '9DB68C', '9E0508', '9E9E9E', '9F5F9F',
        '9F703A', '9F79EE', '9F9F5F', '9FB6CD', 'A020F0', 'A02422', 'A0522D',
        'A1A1A1', 'A2627A', 'A2B5CD', 'A2BC13', 'A2C257', 'A2C93A', 'A2CD5A',
        'A39480', 'A3A3A3', 'A46582', 'A4D3EE', 'A4DCD1', 'A52A2A', 'A5435C',
        'A62A2A', 'A67D3D', 'A68064', 'A6A6A6', 'A6D785', 'A74CAB', 'A78D84',
        'A8A8A8', 'A9A9A9', 'A9A9A9', 'A9ACB6', 'A9C9A4', 'AA00FF', 'AA5303',
        'AA6600', 'AAAAAA', 'AAAAFF', 'AADD00', 'AB82FF', 'ABABAB', 'AC7F24',
        'ADADAD', 'ADD8E6', 'ADEAEA', 'ADFF2F', 'AEBB51', 'AEEEEE', 'AF1E2D',
        'AF4035', 'AFEEEE', 'B0171F', 'B03060', 'B0B0B0', 'B0C4DE', 'B0E0E6',
        'B0E2FF', 'B13E0F', 'B22222', 'B23AEE', 'B272A6', 'B28647', 'B2D0B4',
        'B2DFEE', 'B3432B', 'B3B3B3', 'B3C95A', 'B3EE3A', 'B452CD', 'B4CDCD',
        'B4D7BF', 'B4EEB4', 'B5509C', 'B5A642', 'B5B5B5', 'B62084', 'B6316C',
        'B67C3D', 'B6AFA9', 'B6C5BE', 'B7C3D0', 'B7C8B6', 'B81324', 'B87333',
        'B8860B', 'B8B8B8', 'B9D3EE', 'BA55D3', 'BAAF07', 'BABABA', 'BB2A3C',
        'BBFFFF', 'BC7642', 'BC8F8F', 'BCD2EE', 'BCE937', 'BCED91', 'BCEE68',
        'BDA0CB', 'BDB76B', 'BDBDBD', 'BDFCC9', 'BE2625', 'BEBEBE', 'BEE554',
        'BF3EFF', 'BF5FFF', 'BFBFBF', 'BFEFFF', 'C0C0C0', 'C0D9AF', 'C0D9D9',
        'C0FF3E', 'C1CDC1', 'C1CDCD', 'C1F0F6', 'C1FFC1', 'C2C2C2', 'C3E4ED',
        'C48E48', 'C4C4C4', 'C5C1AA', 'C5E3BF', 'C65D57', 'C67171', 'C6C3B5',
        'C6E2FF', 'C71585', 'C73F17', 'C75D4D', 'C76114', 'C76E06', 'C77826',
        'C7C7C7', 'C82536', 'C8F526', 'C9AF94', 'C9C9C9', 'CAE1FF', 'CAFF70',
        'CBCAB6', 'CC00FF', 'CC1100', 'CC3232', 'CC3299', 'CC4E5C', 'CC7722',
        'CC7F32', 'CC99CC', 'CCCC00', 'CCCCCC', 'CCCCFF', 'CCFFCC', 'CD0000',
        'CD00CD', 'CD1076', 'CD2626', 'CD2990', 'CD3278', 'CD3333', 'CD3700',
        'CD4F39', 'CD5555', 'CD5B45', 'CD5C5C', 'CD6090', 'CD6600', 'CD661D',
        'CD6839', 'CD6889', 'CD69C9', 'CD7054', 'CD7F32', 'CD8162', 'CD8500',
        'CD853F', 'CD8C95', 'CD919E', 'CD950C', 'CD96CD', 'CD9B1D', 'CD9B9B',
        'CDAA7D', 'CDAB2D', 'CDAD00', 'CDAF95', 'CDB38B', 'CDB5CD', 'CDB79E',
        'CDB7B5', 'CDBA96', 'CDBE70', 'CDC0B0', 'CDC1C5', 'CDC5BF', 'CDC673',
        'CDC8B1', 'CDC9A5', 'CDC9C9', 'CDCD00', 'CDCDB4', 'CDCDC1', 'CDCDCD',
        'CDD704', 'CDE472', 'CECC15', 'CFB53B', 'CFCFCF', 'CFD784', 'CFDBC5',
        'D02090', 'D0A9AA', 'D0D2C4', 'D0FAEE', 'D15FEE', 'D19275', 'D1D1D1',
        'D1E231', 'D1EEEE', 'D2691E', 'D2B48C', 'D3BECF', 'D3D3D3', 'D3D3D3',
        'D41A1F', 'D4318C', 'D43D1A', 'D44942', 'D4D4D4', 'D4ED91', 'D5B77A',
        'D66F62', 'D6C537', 'D6D6D6', 'D8BFD8', 'D8D8BF', 'D98719', 'D9D919',
        'D9D9D9', 'D9D9F3', 'DA70D6', 'DAA520', 'DAF4F0', 'DB2645', 'DB2929',
        'DB7093', 'DB70DB', 'DB9370', 'DB9EA6', 'DBDB70', 'DBDBDB', 'DBE6E0',
        'DBFEF8', 'DC143C', 'DC8909', 'DCA2CD', 'DCDCDC', 'DD7500', 'DDA0DD',
        'DE85B1', 'DEB887', 'DEDEDE', 'DFAE74', 'DFFFA5', 'E04006', 'E0427F',
        'E066FF', 'E0D873', 'E0DFDB', 'E0E0E0', 'E0EEE0', 'E0EEEE', 'E0FFFF',
        'E18E2E', 'E2DDB5', 'E31230', 'E3170D', 'E32636', 'E32E30', 'E33638',
        'E35152', 'E3701A', 'E38217', 'E3A869', 'E3CF57', 'E3E3E3', 'E47833',
        'E5BC3B', 'E5E5E5', 'E6B426', 'E6E6FA', 'E6E8FA', 'E79EA9', 'E7C6A5',
        'E8C782', 'E8E8E8', 'E8F1D4', 'E9967A', 'E9C2A6', 'EAADEA', 'EAB5C5',
        'EAEAAE', 'EB5E66', 'EBC79E', 'EBCEAC', 'EBEBEB', 'ECC3BF', 'ECC8EC',
        'ED9121', 'EDC393', 'EDCB62', 'EDEDED', 'EE0000', 'EE00EE', 'EE1289',
        'EE2C2C', 'EE30A7', 'EE3A8C', 'EE3B3B', 'EE4000', 'EE5C42', 'EE6363',
        'EE6A50', 'EE6AA7', 'EE7600', 'EE7621', 'EE7942', 'EE799F', 'EE7AE9',
        'EE8262', 'EE82EE', 'EE8833', 'EE9572', 'EE9A00', 'EE9A49', 'EEA2AD',
        'EEA9B8', 'EEAD0E', 'EEAEEE', 'EEB422', 'EEB4B4', 'EEC591', 'EEC900',
        'EECBAD', 'EECFA1', 'EED2EE', 'EED5B7', 'EED5D2', 'EED6AF', 'EED8AE',
        'EEDC82', 'EEDD82', 'EEDFCC', 'EEE0E5', 'EEE5DE', 'EEE685', 'EEE8AA',
        'EEE8CD', 'EEE9BF', 'EEE9E9', 'EEEB8D', 'EEEE00', 'EEEED1', 'EEEEE0',
        'F08080', 'F0A804', 'F0E68C', 'F0F0F0', 'F0F8FF', 'F0FFF0', 'F0FFFF',
        'F2473F', 'F2F2F2', 'F3E88E', 'F4A460', 'F4F776', 'F54D70', 'F5785A',
        'F5DEB3', 'F5F5DC', 'F5F5F5', 'F5FFFA', 'F64D54', 'F6A4D5', 'F6A8B6',
        'F6C9CC', 'F6CCDA', 'F7B3DA', 'F7F7F7', 'F87531', 'F8F8FF', 'FA1D2F',
        'FA8072', 'FA9A50', 'FAEBD7', 'FAF0E6', 'FAFAD2', 'FAFAFA', 'FBA16C',
        'FBDB0C', 'FBEC5D', 'FC1501', 'FCB514', 'FCD116', 'FCD59C', 'FCDC3B',
        'FCE6C9', 'FCFCFC', 'FCFFF0', 'FDF5E6', 'FDF8FF', 'FEE5AC', 'FEE8D6',
        'FEF0DB', 'FEF1B5', 'FF0000', 'FF0033', 'FF0066', 'FF007F', 'FF00AA',
        'FF00CC', 'FF00FF', 'FF00FF', 'FF030D', 'FF1493', 'FF1CAE', 'FF2400',
        'FF3030', 'FF3300', 'FF3333', 'FF34B3', 'FF3D0D', 'FF3E96', 'FF4040',
        'FF4500', 'FF5333', 'FF5721', 'FF6103', 'FF6347', 'FF6600', 'FF6666',
        'FF69B4', 'FF6A6A', 'FF6EB4', 'FF6EC7', 'FF7216', 'FF7256', 'FF7722',
        'FF7D40', 'FF7F00', 'FF7F24', 'FF7F50', 'FF8000', 'FF8247', 'FF82AB',
        'FF83FA', 'FF8600', 'FF8C00', 'FF8C69', 'FF92BB', 'FF9912', 'FF9955',
        'FFA07A', 'FFA500', 'FFA54F', 'FFA812', 'FFA824', 'FFAA00', 'FFADB9',
        'FFAEB9', 'FFB00F', 'FFB5C5', 'FFB6C1', 'FFB90F', 'FFBBFF', 'FFC0CB',
        'FFC125', 'FFC1C1', 'FFC469', 'FFCC11', 'FFCC99', 'FFCCCC', 'FFD39B',
        'FFD700', 'FFDAB9', 'FFDEAD', 'FFE1FF', 'FFE303', 'FFE4B5', 'FFE4C4',
        'FFE4E1', 'FFE600', 'FFE7BA', 'FFEBCD', 'FFEC8B', 'FFEFD5', 'FFEFDB',
        'FFF0F5', 'FFF5EE', 'FFF68F', 'FFF8DC', 'FFFACD', 'FFFAF0', 'FFFAFA',
        'FFFCCF', 'FFFF00', 'FFFF7E', 'FFFFAA', 'FFFFCC', 'FFFFE0', 'FFFFF0',
        'FFFFFF'
    );
    return \@Codes;
}

1;
