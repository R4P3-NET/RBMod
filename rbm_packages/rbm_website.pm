package rbm_website;
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
#            This product includes GeoLite data created by MaxMind,
#                    available from http://www.maxmind.com
use 5.10.0;
use strict;
use warnings;
use lib './rbm_packages';
use rbm_parent;
my $nl = "\r\n";

sub Rbm_CleanINPUT {
    my ($chat,$settings_ref) = @_;
    my $FORM;
    $chat =~ s`^GET /\S+\?``;
    $chat =~ s`HTTP/1.[01]``;
    $chat =~ s`\s+$|^\s+``;
    my @pairs = split(/\&/, $chat);
    foreach my $pair (@pairs) {
        my ($name, $value) = split(/=/, $pair);
        $value =~ tr/\+/ /;
        $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
        $FORM->{$name} = $value || 'Null';
    }
    return $FORM;       # return reference
}

sub Rbm_AccessCookie {
    my ( $client, $cookie ) = @_;
    $cookie = './rbm_webserver/cookies/'.$cookie;
    return unless -e $cookie;
    my $ClientAddr = $client->peerhost();
    my @Info = ();
    open COOKIE, "<",$cookie or die "Error: ".$!;
    while ( <COOKIE> ) {
        @Info = $_ =~ /^SessionID: (\S+) SessionIP: (\S+)/;
    }
    close COOKIE;
}

sub Rbm_MakeCookie {
    my ($client,$RandomPWD_ref) = @_;
    my ($RandomPWD) = $$RandomPWD_ref;
    my $ClientAddr = $client->peerhost();
    open COOKIE, ">",'./rbm_webserver/cookies/'.$RandomPWD or die "Error: ".$!;
    syswrite COOKIE, 'SessionID: '.$RandomPWD.' SessionIP: '.$ClientAddr."\n";
    close COOKIE;
}

sub Rbm_DeleteCookie {
    my $cookie = shift;
    $cookie = './rbm_webserver/cookies/'.$cookie;
    unlink $cookie if -e $cookie;
}

sub Rbm_Redirect {
    my ($client,$cookie) = @_;
    $cookie = 'blank' unless $cookie;
    syswrite $client, <<ENDHTML;
<!DOCTYPE html>
    <html>
        <head>
            <title>Login Failed!</title>
            <META http-equiv="Set-cookie" content="RbMod\=$cookie;Expires=Wed, 09-Jun-2000 10:00:00 GMT;path=/">
            <META http-equiv="refresh" content="0; URL=/">
        </head>
        <body>
        <br><br>
        <center>
            Error! Please Try Again.
        </center>
        </body>
    </html>
ENDHTML
}

sub Rbm_Login {
    my $client = shift;

    syswrite $client, <<ENDHTML;
<!DOCTYPE html>
<HTML>
    <HEAD>
        <link rel="icon" type="image/png" href="./rbm_webserver/images/favicon.png" />
        <TITLE>RbMod Login</TITLE>
    </HEAD>
    <BODY>

    <font type="arial">
    <div style="position:absolute; top:50px;left:50%;margin-left:-300px;
        text-align:center; width:600px; height:400px;
        padding-left:13px; padding-right:13px; z-index:16;">

        <img src=/rbm_webserver/images/rb.gif width="600px" height="400px">
        <br><br>
    </div>

    <DIV STYLE="position:absolute; width:500; border-left:thin solid black;
        border-right:thin solid black; border-top:thin solid black;
        display:block; z-index:15; top:453px; left:50%; padding-top:3px; height:25px;
        margin-left:-250px; padding:12px; padding-top:0px; background-color:#a7adbb;">
        <FONT COLOR="WHITE">Control Center Login</FONT>
    </DIV>

    <FONT TYPE="ARIAL">

    <DIV STYLE="position:absolute; width:500px; border:thin solid black;
        border-bottom:solid 1px black;
        display:block; z-index:15; top:475px; left:50%; margin-top:0px;
        margin-left:-250px; padding:12px; padding-top:0px; background-color:#e8e9eb;">

        <FORM ACTION="Login" method="get">
            <FONT SIZE="1" type="arial">Sign into Rb Modification for Teamspeak3</FONT><BR><BR>

            <div>
                <DIV STYLE="Float:Left; Width:195px; text-align:right; padding-right:5px;">
                    Username:
                </DIV>
                <DIV STYLE="Float:Left; Width:300px;"><input type=text name="name"></DIV>
            </div>

            <div>
                <DIV STYLE="Float:Left; Width:195px; text-align:right; padding-right:5px;">
                    Password:
                </DIV>
                <DIV STYLE="Float:Left; Width:300px;"><input type=password name="pass"></DIV>
            </div>

            <DIV STYLE="Float:Left; Width:318px; Text-Align: Right;"><input type=submit value="Login"><input type=reset></DIV>

        </FORM>
    </DIV>
    </FONT>
    </BODY>
</HTML>
ENDHTML
}

sub Rbm_LoginProcess {
    my ($client,$request,$settings_ref) = @_;
    my ($SET_Login) = join('',$settings_ref->{'WebServer_Login'});
    my ($SET_Pass)  = join('',$settings_ref->{'WebServer_Password'});
    my $FORM = Rbm_CleanINPUT( $request );

    if ( exists $FORM->{'name'} and $FORM->{'name'} eq $SET_Login and
         exists $FORM->{'pass'} and $FORM->{'pass'} eq $SET_Pass ) {
         my ($RandomPWD_ref) = rbm_parent::Rbm_RandomPassword(50);
         &Rbm_MakeCookie($client,$RandomPWD_ref);

        syswrite $client, <<ENDHTML;
        <html>
            <head>
                <title>Varification Succeeded!</title>
                <META http-equiv="Set-cookie" content="RbMod\=$$RandomPWD_ref;path=/">
                <META http-equiv="refresh" content="0; URL=/">
            </head>
            </body>
        </html>
ENDHTML
    }
    else {
        &Rbm_Redirect($client);
    }
}

# Control-Panel
sub Rbm_Launch {
    my ($client,$request,$settings_ref) = @_;

    syswrite $client, <<ENDHTML;
<!DOCTYPE html>
<html>
    <head>
        <link rel="shortcut icon" href="/rbm_webserver/images/favicon.png">
        <title>RbMod Control Center</title>
        <meta http-equiv="Content-language" content="en" />

        <style type="text/css">
            body {
                background-color: #eceef2;
            }
        </style>

        <script language="javascript" type="text/javascript">
        <!--
        var AjaxRequest  = null;
        var AjaxRequest2 = null;
        var screenheight = null;
        var ActiveAjax   = 'query';
        var QueryTimer   = null;
        var QuerySave    = null;

        function Ping() {
            if (AjaxRequest) {
                return AjaxRequest;
            }
            if (window.XMLHttpRequest) {
                AjaxRequest = new XMLHttpRequest();
            } else if (window.ActiveXObject) {
                try {
                    AjaxRequest = new ActiveXObject("Msxml2.XMLHTTP");
                }
                catch (e) {
                    try {
                       AjaxRequest = new ActiveXObject("Microsoft.XMLHTTP");
                    } catch (f) {}
                }
            }
            return AjaxRequest;
        }

        function Ping2() {
            if (AjaxRequest2) {
                return AjaxRequest2;
            }
            if (window.XMLHttpRequest) {
                AjaxRequest2 = new XMLHttpRequest();
            } else if (window.ActiveXObject) {
                try {
                    AjaxRequest2 = new ActiveXObject("Msxml2.XMLHTTP");
                }
                catch (e) {
                    try {
                       AjaxRequest2 = new ActiveXObject("Microsoft.XMLHTTP");
                    } catch (f) {}
                }
            }
            return AjaxRequest2;
        }

        function LogLoad(logname) {
            document.getElementById("PleaseWait").style.display = "block";
            var target_div = document.getElementById("Inner2");
            var xhr = Ping();
            xhr.onreadystatechange = function() {
                if (xhr.readyState == 4 && xhr.status == 200) {
                    target_div.innerHTML = xhr.responseText;
                    target_div.scrollTop = target_div.scrollHeight;
                    document.getElementById("PleaseWait").style.display = "none";
                }
            };
            xhr.open("GET", "/logs/" + logname);
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; Charset=UTF-8');
            xhr.send(null);
        }

        function PostQuery() {
            document.getElementById("PleaseWait").style.display = "block";
            var data = document.getElementById('QueryPost').value;
            var target_div = document.getElementById("ReceiveQuery");
            var xhr = Ping();
            xhr.onreadystatechange = function() {
                if (xhr.readyState == 4 && xhr.status == 200) {
                    if (QuerySaved != xhr.responseText) {
                        target_div.innerHTML = xhr.responseText;
                        target_div.scrollTop = target_div.scrollHeight;
                        QuerySaved = xhr.responseText;
                        document.getElementById("PleaseWait").style.display = "none";
                    }
                }
            };
            xhr.open("POST", '/querypost?Key=' + data + 'ENDLINE');
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; Charset=UTF-8');
            xhr.send(null);
        }

        function QueryTS3() {
            var target_div = document.getElementById("ReceiveQuery");
            document.getElementById("PleaseWait").style.display = "block";
            var xhr = Ping();
            xhr.onreadystatechange = function() {
                if (xhr.readyState == 4 && xhr.status == 200) {
                    if (QuerySaved != xhr.responseText) {
                        target_div.innerHTML = xhr.responseText;
                        target_div.scrollTop = target_div.scrollHeight;
                        QuerySaved = xhr.responseText;
                        document.getElementById("PleaseWait").style.display = "none";
                    }
                }
            };
            xhr.open("GET", "/querydata" + ';Time=' + new Date().getTime(), true);
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; Charset=UTF-8');
            xhr.send(null);
        }

        function MenuSwitch(linked,wide,ignore,extra) {
            clearInterval(QueryTimer);
            var target_div = document.getElementById("ajaxbody");
            document.getElementById("PleaseWait").style.display = "block";

            // Unhighlight previous button
            if (ActiveAjax) {
                document.getElementById(ActiveAjax + '_button').style.display  = 'none';
                document.getElementById(ActiveAjax + '_circuit').style.display = 'none';
            }
            else {
                linked = 'settings';
            }
            ActiveAjax = linked;

            // highlight active button
            document.getElementById(linked + '_button').style.display  = 'block';
            document.getElementById(linked + '_circuit').style.display = 'block';

            var xhr = Ping();
            xhr.onreadystatechange = function() {
                if (xhr.readyState == 4 && xhr.status == 200) {

                    if(wide) {
                        target_div = document.getElementById("ajaxbodywide");
                        document.getElementById('ajaxbodywide').style.display    = 'block';
                        document.getElementById('ajaxbody').style.display        = 'none';
                        document.getElementById('bodylefttop').style.background  = 'url(/rbm_webserver/images/main_lefttop_logs.png)';
                        document.getElementById('bodyrighttop').style.background = 'url(/rbm_webserver/images/main_righttop_logs.png)';
                        document.getElementById('bodyleftbot').style.display     = 'none';
                        document.getElementById('bodyrightbot').style.display    = 'none';
                        target_div.innerHTML = xhr.responseText;
                        screenheight = document.getElementById('Inner2').offsetHeight;
                        document.getElementById('Flowleft2').style.height  = screenheight - 47 + "px";
                        document.getElementById('Flowright2').style.height = screenheight  - 47 + "px";

                    }
                    else {
                        document.getElementById('ajaxbodywide').style.display    = 'none';
                        document.getElementById('ajaxbody').style.display        = 'block';
                        document.getElementById('bodylefttop').style.background  = 'url(/rbm_webserver/images/main_lefttop.png)';
                        document.getElementById('bodyrighttop').style.background = 'url(/rbm_webserver/images/main_righttop.png)';
                        document.getElementById('bodyleftbot').style.display     = 'block';
                        document.getElementById('bodyrightbot').style.display    = 'block';
                        target_div.innerHTML = xhr.responseText;
                        if (!ignore) {
                            screenheight = document.getElementById('Inner').offsetHeight;
                            document.getElementById('Flowleft').style.height  = screenheight - 509 + "px";
                            document.getElementById('Flowright').style.height = screenheight - 468 + "px";
                        }

                    }
                    document.getElementById("PleaseWait").style.display   = "none";
                }
            };
            if (extra) {
                xhr.open("POST", "/" + linked + extra);
            }
            else {
                xhr.open("POST", "/" + linked);
            }
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; Charset=UTF-8');
            xhr.send(null);
        }

        function MenuOut(target) {
            if (ActiveAjax != target) {
                document.getElementById(target + '_button').style.display = 'none';
            }
        }

        function pause(numberMillis) {
            var now = new Date();
            var exitTime = now.getTime() + numberMillis;
            while (true) {
                now = new Date();
                if (now.getTime() > exitTime) {
                    return;
                }
            }
        }

        function Send_MOTD(formname,target,formhandler) {
            var thing = document.getElementById("EditMOTD").value;
            var thisform = document.getElementById( formname );
            var formdata = "";

            thing = thing.replace(/\\n|\\r/g, "-|-\\n");
            document.getElementById("EditMOTD").style.display="none";
            document.getElementById("EditMOTD").value = thing;
            target   = document.getElementById( target );


            for (i=0; i < thisform.length; i++) {
                if(thisform.elements[i].type == "text"){
                    formdata = formdata + thisform.elements[i].name + "=" + escape(thisform.elements[i].value) + "&";
                }else if(thisform.elements[i].type == "textarea"){
                    formdata = formdata + thisform.elements[i].name + "=" + escape(thisform.elements[i].value) + "&";
                }else if(thisform.elements[i].type == "checkbox"){
                    formdata = formdata + thisform.elements[i].name + "=" + thisform.elements[i].checked + "&";
                }else if(thisform.elements[i].type == "radio"){
                    if(thisform.elements[i].checked==true){
                        formdata = formdata + thisform.elements[i].name + "=" + thisform.elements[i].value + "&";
                    }
                } else {
                    formdata = formdata + thisform.elements[i].name + "=" + escape(thisform.elements[i].value) + "&";
                }
            }

            // Build array from form data
            var array = formdata.match(/[\\s\\S]{1,512}/g) || [];

            // Send remaining array elements
            var xmlhttp = Ping2();
            for(i = 0; i < array.length; i++){
                xmlhttp.open("POST", "/" + formname + "?" + formhandler + " SPLITBEGIN " + array[i] + " SPLITEND", true);
                xmlhttp.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; Charset=UTF-8');
                xmlhttp.send(null);
                pause(200);
            }

            xmlhttp.open("POST", '/' + formname + '?' + formhandler + ' SPLITENDALL', true);
            xmlhttp.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; Charset=UTF-8');
            xmlhttp.send(null);
            MenuSwitch('motd','',1);
            pause(500);
            MenuSwitch('motd','',1);
        }

        function form_success_client(formname,target,formhandler) {
            var thisform = document.getElementById( formname );
            target       = document.getElementById( target );
            var formdata = "";

            try {var xmlhttp = window.XMLHttpRequest?new XMLHttpRequest(): new ActiveXObject("Microsoft.XMLHTTP");} catch (e) { alert("Error: Could not load page.");}

            for (i=0; i < thisform.length; i++) {
                if(thisform.elements[i].type == "text"){
                    formdata = formdata + thisform.elements[i].name + "=" + escape(thisform.elements[i].value) + "&";
                }else if(thisform.elements[i].type == "textarea"){
                    formdata = formdata + thisform.elements[i].name + "=" + escape(thisform.elements[i].value) + "&";
                }else if(thisform.elements[i].type == "checkbox"){
                    formdata = formdata + thisform.elements[i].name + "=" + thisform.elements[i].checked + "&";
                }else if(thisform.elements[i].type == "radio"){
                    if(thisform.elements[i].checked==true){
                        formdata = formdata + thisform.elements[i].name + "=" + thisform.elements[i].value + "&";
                    }
                } else {
                    formdata = formdata + thisform.elements[i].name + "=" + escape(thisform.elements[i].value) + "&";
                }
            }

            // Build array from form data
            var array = formdata.match(/[\\s\\S]{1,512}/g) || [];

            // Send remaining array elements
            var trig;
            for(i = 0; i < array.length; i++){
                xmlhttp.open("POST", '/' + formname + '?' + formhandler + ' SPLITBEGIN ' + array[i] + ' SPLITEND', true);
                xmlhttp.send(null);
                trig = 1;
                pause(200);
            }

            xmlhttp.open("POST", '/' + formname + '?' + formhandler, true );
            xmlhttp.send(null);

        }

        //-->
        </script>
    </head>

    <body>
    <div style="position:absolute; top:0px;left:50%;margin-left:-512px;
        width:1024px; height:724px; z-index:16;">

        <div style="position:absolute; top:0px;left:0px;
            width:1024px; height:387px; z-index:16;
            background-image: URL('/rbm_webserver/images/main_top.png');
            background-repeat: no-repeat;">
        </div>

        <div style="position:absolute; top:231px;left:55px;
            width:936px; height:288px; z-index:1;
            background-image: URL('/rbm_webserver/images/main_backdrop.png');
            background-repeat: no-repeat;">
        </div>

        <div id="bodylefttop" style="position:absolute; top:387px;left:0px;
            width:177px;height:360px;z-index:16; display:block;
            background-image: URL('/rbm_webserver/images/main_lefttop.png');">
        </div>

        <div id="bodyleftbot" style="position:absolute; top:747px;left:0px;
            width:177px;height:264px;z-index:16; display:block;
             background-image: URL('/rbm_webserver/images/main_leftbot.png');">
        </div>


        <div id="bodyrighttop" style="position:absolute; top:387px;right:0px;
            width:177px;height:360px;z-index:16; display:block;
            background-image: URL('/rbm_webserver/images/main_righttop.png');">
        </div>

        <div id="bodyrightbot" style="position:absolute; top:747px;right:0px;
            width:177px;height:277px;z-index:16; display:block;
             background-image: URL('/rbm_webserver/images/main_rightbot.png');">
        </div>

        <div id="PleaseWait" style="position:absolute; top:385px; left:50%;margin-left:-100px;
            width:200px; height:40px; z-index:16; display:block; text-align:center;">
            Please wait a moment...
        </div>

        <div ID="ajaxbody" style="position:absolute; top:400px;left:50%;margin-left:-320px;
            width:640px; height:600px; z-index:16; border: solid 0px #e5e7f5;">
             <div ID="Flowleft" style="position:absolute; top:580px;left:-15px;
                width:674px;z-index:18; height:5px; background-repeat:repeat-x;
                background-image: URL('/rbm_webserver/images/main_flow_x.png');">
            </div>
            <div ID="Flowright" style="position:absolute; top:539px;right:-20px;
                width:5px;z-index:18; height:45px; background-repeat:repeat-y;
                background-image: URL('/rbm_webserver/images/main_flow.png');">
            </div>
        </div>

        <div ID="ajaxbodywide" style="position:absolute; top:380px;left:50%;margin-left:-512px;
            width:1024px; height:800px; z-index:16; border: solid 0px #e5e7f5; display: none;">
        </div>

        <div ID="grid1" style="position:absolute; top:353px;right:46px;
            text-align:center;width:154px;height:153px;z-index:17;
            background-image: url('/rbm_webserver/images/main_right_grid1.png');
            display: block; overflow: hidden;">
        </div>
        <div ID="grid1animate" style="position:absolute; top:353px;right:46px;
            text-align:center;width:154px;height:153px;z-index:-1;
            background-image: url('/rbm_webserver/images/hl_grid1.gif');
            display: none; overflow: hidden;">
        </div>

        <form id="FormGrid1" ACTION="Grid1" method="POST">
            <div ID="grid1_connect" style="position:absolute; top:352px;right:39px; display: block;
                text-align:center;width:134px;height:47px;z-index:21; border: solid 0px red;
                background-image: url('/rbm_webserver/images/connect.png');"
                onmouseover="document.getElementById('grid1animate').style.display='block';
                    this.style.cursor='pointer';
                    this.style.background='url(/rbm_webserver/images/connecthl.png)';"
                onmouseout="document.getElementById('grid1animate').style.display='none';
                    this.style.cursor='default';
                    this.style.background='url(/rbm_webserver/images/connect.png)';"
                onclick="javascript:form_success_client('FormGrid1','ajaxbody','Connect Mod'); return false;">
            </div>
            <div ID="grid1_disconnect" style="position:absolute; top:399px;right:39px; display: block;
                text-align:center;width:134px;height:24px;z-index:21; border: solid 0px red;
                background-image: url('/rbm_webserver/images/disconnect.png');"
                onmouseover="document.getElementById('grid1animate').style.display='block';
                    this.style.cursor='pointer';
                    this.style.background='url(/rbm_webserver/images/disconnecthl.png)';"
                onmouseout="document.getElementById('grid1animate').style.display='none';
                    this.style.cursor='default';
                    this.style.background='url(/rbm_webserver/images/disconnect.png)';"
                onclick="javascript:form_success_client('FormGrid1','ajaxbody','Disconnect Mod'); return false;">
            </div>
            <div ID="grid1_reconnect" style="position:absolute; top:423px;right:39px; display: block;
                text-align:center;width:134px;height:24px;z-index:21; border: solid 0px red;
                background-image: url('/rbm_webserver/images/reconnect.png');"
                onmouseover="document.getElementById('grid1animate').style.display='block';
                    this.style.cursor='pointer';
                    this.style.background='url(/rbm_webserver/images/reconnecthl.png)';"
                onmouseout="document.getElementById('grid1animate').style.display='none';
                    this.style.cursor='default';
                    this.style.background='url(/rbm_webserver/images/reconnect.png)';"
                onclick="javascript:form_success_client('FormGrid1','ajaxbody','Reconnect Mod'); return false;">
            </div>
            <div ID="grid1_reboot" style="position:absolute; top:447px;right:39px; display: block;
                text-align:center;width:134px;height:47px;z-index:21; border: solid 0px red;
                background-image: url('/rbm_webserver/images/reboot.png');"
                onmouseover="document.getElementById('grid1animate').style.display='block';
                    this.style.cursor='pointer';
                    this.style.background='url(/rbm_webserver/images/reboothl.png)';"
                onmouseout="document.getElementById('grid1animate').style.display='none';
                    this.style.cursor='default';
                    this.style.background='url(/rbm_webserver/images/reboot.png)';"
                onclick="javascript:form_success_client('FormGrid1','ajaxbody','Reboot Mod'); return false;">
            </div>
        </form>

        <div ID="motd_button" style="position:absolute; top:282px;right:394px;
            text-align:center;width:86px;height:65px;z-index:17;
            background-image: url('/rbm_webserver/images/hl_motd.png');
            display: none;">
        </div>
        <div ID="motd_circuit" style="position:absolute; top:321px;left:264px;
            text-align:center;width:17px;height:17px;z-index:20;
            background-image: url('/rbm_webserver/images/hl_circuit_blue.png');
            display: none;">
        </div>
        <div ID="motd_cmd" style="position:absolute; top:280px;right:394px;
            text-align:center;width:86px;height:65px;z-index:21;
            background-image: url('/rbm_webserver/images/loader.png');"

            onmouseover="document.getElementById('motd_button').style.display='block';
                this.style.cursor='pointer';"
            onmouseout="javascript:MenuOut('motd');
                this.style.cursor='default';"
            onclick="javascript:MenuSwitch('motd','',1);">
        </div>

        <div ID="db_button" style="position:absolute; top:282px;right:304px;
            text-align:center;width:86px;height:67px;z-index:17;
            background-image: url('/rbm_webserver/images/hl_db.png');
            display: none;">
        </div>
        <div ID="db_circuit" style="position:absolute; top:321px;left:264px;
            text-align:center;width:17px;height:17px;z-index:20;
            background-image: url('/rbm_webserver/images/hl_circuit_blue.png');
            display: none;">
        </div>
        <div ID="db_cmd" style="position:absolute; top:280px;right:300px;
            text-align:center;width:86px;height:65px;z-index:21;
            background-image: url('/rbm_webserver/images/loader.png');"

            onmouseover="document.getElementById('db_button').style.display='block';
                this.style.cursor='pointer';"
            onmouseout="javascript:MenuOut('db');
                this.style.cursor='default';"
            onclick="javascript:MenuSwitch('db',1);">
        </div>

        <div ID="settings_button" style="position:absolute; top:405px;left:18px;
            text-align:center;width:113px;height:183px;z-index:17;
            background-image: url('/rbm_webserver/images/hl_settings.png');
            display: none;">
        </div>
        <div ID="settings_circuit" style="position:absolute; top:322px;left:204px;
            text-align:center;width:17px;height:17px;z-index:20;
            background-image: url('/rbm_webserver/images/hl_circuit_green.png');
            display: none;">
        </div>
        <div ID="settings_cmd" style="position:absolute; top:468px;left:14px;
            text-align:center;width:120px;height:43px;z-index:21;
            background-image: url('/rbm_webserver/images/loader.png');"

            onmouseover="document.getElementById('settings_button').style.display='block';
                this.style.cursor='pointer';"
            onmouseout="javascript:MenuOut('settings');
                this.style.cursor='default';"
            onclick="javascript:MenuSwitch('settings');">
        </div>

        <div ID="logs_button" style="position:absolute; top:457px;left:30px;
            text-align:center;width:115px;height:158px;z-index:17;
            background-image: url('/rbm_webserver/images/hl_logs.png');
            display: none;">
        </div>
        <div ID="logs_circuit" style="position:absolute; top:321px;left:234px;
            text-align:center;width:17px;height:17px;z-index:20;
            background-image: url('/rbm_webserver/images/hl_circuit_yellow.png');
            display: none;">
        </div>
        <div ID="logs_cmd" style="position:absolute; top:511px;left:32px;
            text-align:center;width:108px;height:43px;z-index:21;
            background-image: url('/rbm_webserver/images/loader.png');"

            onmouseover="document.getElementById('logs_button').style.display='block';
                this.style.cursor='pointer';"
            onmouseout="javascript:MenuOut('logs');
                this.style.cursor='default';"
            onclick="javascript:MenuSwitch('logs',1);">
        </div>

        <div ID="query_button" style="position:absolute; top:483px;left:45px;
            text-align:center;width:127px;height:140px;z-index:17;
            background-image: url('/rbm_webserver/images/hl_help.png');
            display: none;">
        </div>
        <div ID="query_circuit" style="position:absolute; top:321px;left:264px;
            text-align:center;width:17px;height:17px;z-index:20;
            background-image: url('/rbm_webserver/images/hl_circuit_blue.png');
            display: none;">
        </div>
        <div ID="query_cmd" style="position:absolute; top:555px;left:51px;
            text-align:center;width:108px;height:43px;z-index:21;
            background-image: url('/rbm_webserver/images/loader.png');"

            onmouseover="document.getElementById('query_button').style.display='block';
                this.style.cursor='pointer';"
            onmouseout="javascript:MenuOut('query');
                this.style.cursor='default';"
            onclick="javascript:MenuSwitch('query','',1);
                QuerySaved = null;
                javascript:setTimeout('QueryTS3();', 10);
                javascript:setTimeout('QueryTS3();', 1000);
                javascript:QueryTimer = setInterval('QueryTS3();', 2000);">
        </div>

        <div id="logout_button" name="logout_button" style="position:absolute; top:265px;left:811px;
            text-align:center;width:148px;height:90px;z-index:17;
            background-image: url('/rbm_webserver/images/hl_logout.png');
            display: none;">
        </div>
        <div id="logout_circuit" name="logout_circuit" style="position:absolute; top:508px;left:920px;
            text-align:center;width:17px;height:17px;z-index:20;
            background-image: url('/rbm_webserver/images/hl_circuit_red.gif');
            display:none;">
        </div>
        <div id="logout_cmd" name="logout_cmd" style="position:absolute; top:285px; left:815px;
            text-align:center; width:136px; height:65px; z-index:21; display: inline;
            background-image: url('/rbm_webserver/images/loader.png');"

            onmouseover="document.getElementById('logout_button').style.display='block';
                document.getElementById('logout_circuit').style.display='block';
                this.style.cursor='pointer';"

            onmouseout="javascript:MenuOut('logout');
                document.getElementById('logout_circuit').style.display='none';
                this.style.cursor='default';"
            onclick="window.location.href='/Logout'">
        </div>
    </div>
    </body>
</html>
ENDHTML
}

sub Rbm_Settings {
    my $client = shift;
    my $settings_ref = &rbm_parent::Rbm_LoadConfigs('rbm_settings.cf');

    syswrite $client, <<ENDHTML;
    <DIV ID="Inner" STYLE="position:absolute; top:30px; left:0px; width:100%;" >

        <FORM ID="FormSettings" ACTION="Settings" method="post">
ENDHTML

    for my $Key ( sort keys %$settings_ref ) {
        my $Value = $settings_ref->{$Key};

        syswrite $client, <<ENDHTML;
        <DIV STYLE="float:left; width: 100%;">
            <DIV STYLE="float:left; width:318px;">
                $Key
            </DIV>
            <DIV STYLE="float:left; width:318px; padding: 2px;">
                <INPUT type="text" name="$Key" value="$Value" size="25"
                    style="color: #5E4B2E; font-family: Verdana; font-size: 12px; background-color: #F4F6F8; width:318px;"></INPUT>
            </DIV>
        </DIV>

ENDHTML
    }
    syswrite $client, <<ENDHTML;

        <div ID="Flowleft" style="position:absolute; top:551px;left:-19px;
                width:5px;z-index:18; height:auto; background-repeat:repeat-y;
                background-image: URL('/rbm_webserver/images/main_flow.png');">
        </div>
        <div ID="Flowright" style="position:absolute; top:510px;right:-20px;
                width:5px;z-index:18; height:auto; background-repeat:repeat-y;
                background-image: URL('/rbm_webserver/images/main_flow.png');">
        </div>

        <div style="position:absolute; top:100px;right:-140px;text-align:center;">
            <input type=button value="Save & Apply" onclick="javascript:form_success_client('FormSettings','ajaxbody','SaveApply'); javascript:MenuSwitch('settings'); javascript:pause(500); javascript:MenuSwitch('settings');"><br>
            <input type=button value="Save" onclick="javascript:form_success_client('FormSettings','ajaxbody',this.value); javascript:MenuSwitch('settings'); javascript:pause(500); javascript:MenuSwitch('settings');"><br>
            <input type=reset value="Reset"><br>
        </div>

        </FORM>
    </DIV>
ENDHTML
}

sub Rbm_SaveSettings {
    my $request = shift;
    $request =~ s/\&\=Save \& Apply\&\=Save\&\=Reset\&.*?$//i;
    my @array = split /\&/,$request;
    say scalar(@array);
    return unless scalar(@array) == 176;
    open(my $SETTINGS, ">",'./rbm_settings.cf');
    syswrite $SETTINGS, qq`# Note: The 'Traffic Meter' and 'Delete Dormant Channels' are disabled`.$nl;
    syswrite $SETTINGS, qq`# by default. Please read each of the settings and possibly make a`.$nl;
    syswrite $SETTINGS, qq`# backup / snapshot of your server before experimenting with each.`.$nl.$nl;
    for (@array) {
        my ($Key,$Value) = $_ =~ /(\S+)\=(.*?)$/;
        next unless defined $Key;
        syswrite $SETTINGS, $Key . ' = '. $Value.$nl;
    }
    close $SETTINGS;
    if ( $request =~ /SaveApply/i ) {
        &rbm_parent::Rbm_ParentCaching('SaveApply');
    }
}

sub Rbm_MOTD {
    my ($client,$request) = @_;
    my $MOTDLocal = './rbm_stored/rbm_motd.cf';
    open(my $File, "<",$MOTDLocal);
    my @MOTD = <$File>;
    close $File;
    syswrite $client, <<ENDHTML;
    <div style="position:absolute; top:580px;left:-15px;
        width:674px;z-index:18; height:5px; background-repeat:repeat-x;
        background-image: URL('/rbm_webserver/images/main_flow_x.png');">
    </div>
    <div style="position:absolute; top:539px;right:-20px;
        width:5px;z-index:18; height:45px; background-repeat:repeat-y;
        background-image: URL('/rbm_webserver/images/main_flow.png');">
    </div>

    <FORM ID="MOTDForm" action="EditMOTD" method="POST">

    <div STYLE="position:absolute; top:16px; left:50%; width:646px;
        height:545px; margin-left:-324px; border: solid 1px navy; display:block;
        background:#e6ecf9;">

        <TEXTAREA ID="EditMOTD" NAME='EditMOTD' MAXLENGTH="40000"
            STYLE="overflow:hidden; overflow-y:auto; background-color:#efeffa;
            width:642px; height:540px; resize:none;">
ENDHTML

    foreach my $line ( @MOTD ) {
        $line =~ s/[\n\r]//gi;

        syswrite $client, <<ENDHTML;
$line
ENDHTML
    }
    syswrite $client, <<ENDHTML;
        </TEXTAREA>
        </div>
        <div style="position:absolute; top:180px;right:-110px;text-align:center;">
            <input type=button value="Save" onclick="javascript:Send_MOTD('MOTDForm','ajaxbody',this.value); return false;"><br>
            <input type=reset value="Reset"><br>
        </div>
    </FORM>
ENDHTML

}

sub Rbm_SaveMOTD {
    my $request = shift;

    $request =~ s/^.*?EditMOTD=//gi;
    $request =~ s/\-\|\-[\s]?/\n/gi;
    $request =~ s/[\s\n\t]+$//gi;
    $request =~ s/^[\s]*//gi;
    $request =~ s/\n[\s]*\n$/\n/gi;
    $request =~ s/\s{8}//gi;
    $request =~ s/\%uFEFF//gi;
    $request =~ s/\&\=Save\&\=Reset\&.*?$//gi;

    open(my $MOTD, ">",'./rbm_motd.cf');
    syswrite $MOTD, $request . "\n";
    close $MOTD;
}

sub Rbm_loadlogs {
    my ($client,$logfile) = @_;
    $logfile = './rbm_logs/'.$logfile;
    open F, "<$logfile" or &rbm_parent::Rbm_Log("INFO  \t- WebSite       \t- Log Load Error: ".$1);
    my @f = <F>;
    close F;

    syswrite $client, qq`<font type="arial" size="2">`;

    foreach my $line ( @f ) {
        my ($Date,$Status,$Type,$Value) = $line =~ /^(.*?)\s{2,}(.*?)\- (.*?)\s+\- (.*?)$/;

        next unless $Value;

        syswrite $client, <<ENDHTML;

        <div style="width:100%; height: 17px;">
            <div style="float:left; width:290px;">
               $Date
            </div>
            <div style="float:left; width:75px;">
               $Status
            </div>
            <div style="float:left; width:130px;">
               $Type
            </div>
            <div style="float:left; width:440px;">
               $Value
            </div>
        </div>
ENDHTML
    }
    syswrite $client, qq`</font></div>`;
}

sub Rbm_logs {
    my ($client,$request) = @_;
    my $dirname = './rbm_logs';
    opendir my($dh), $dirname or &rbm_parent::Rbm_Log("INFO  \t- WebSite       \t- Log Page Error: ".$1);
    my @files = readdir $dh;
    closedir $dh;

    syswrite $client, <<ENDHTML;

    <div ID="Flowleft2" style="position:absolute; top:367px;left:28px;
            width:5px;z-index:18; height:100%; background-repeat:repeat-y;
            background-image: URL('/rbm_webserver/images/main_flow.png');">
    </div>
    <div ID="Flowright2" style="position:absolute; top:367px;right:28px;
            width:5px;z-index:18; height:100%; background-repeat:repeat-y;
            background-image: URL('/rbm_webserver/images/main_flow.png');">
    </div>

   <div ID="Inner2" STYLE="position:absolute; top:250px; left:50%; width:958px;
       height:660px; margin-left:-480px; border: solid 1px navy; display:block;
       overflow-y:auto; overflow-x:hidden; background-color: #FBFBFE; z-index:30;">
   </div>

   <div style="position:absolute; top:30px; left:50%; margin-left:-200px;
       width:400px; height:210px; overflow:hidden; border: solid 1px navy;
       display:block; overflow-y:auto;">

ENDHTML

    foreach my $logfile ( reverse sort @files ) {
        next unless $logfile =~ /\.log/;
        syswrite $client, <<ENDHTML;
        <div style=""
            onmouseover="this.style.cursor='pointer'"
            onmouseout="this.style.cursor='default'"
            onclick="javascript:LogLoad('$logfile');">

            $logfile
        </div>
ENDHTML
    }
    syswrite $client, qq`</div>`;
}

sub Rbm_ClientDBEdit {
    my ($client,$request) = @_;

#    if ( $request =~ /PurgeSingle/ ) {
    my (@PurgeList) = $request =~ /(\d+)\=true/sgi;
#    }
    open my $FFCLList, "<",'rbm_stored/rbm_clients.cf' or die 'Can\'t load rbm_clients.cf! '.$!;
    my $Data = <$FFCLList>;
    close $FFCLList;
    foreach my $DeleteID (@PurgeList) {
        $Data =~ s/DB=$DeleteID.+?\|//i;
    }
    open $FFCLList, ">",'rbm_stored/rbm_clients.cf' or die 'Can\'t load rbm_clients.cf! '.$!;
    print $FFCLList $Data;
    close $FFCLList;
    &rbm_parent::Rbm_ParentCaching('DBReload');
}

sub Rbm_ClientDB {
    my ($client,$request) = @_;
    my $DBFile = './rbm_stored/rbm_clients.cf';
    open my $File, "<",$DBFile or die 'Error '.$!;
    my @DB = split /\|/,<$File>;
    close $File;
    my $Size = scalar(@DB);
    my $Headercolor = 'silver';
    my %DBHash = ();
    my ($clDBID,$CLNick,$CLIP,$DNS,$CLHops,$CLHopsRead,$CLTotalTime,$CLastOnline,
            $CLastChan,$UserGroups,$Punished,$Sent,$Recv);
    my $cnt = 1;
    my $cntr = 0;
    my @options = ('25','50','100','200','500');
    my $ActiveHL = 'transparent';

    sub sortedHashKeysByValueDescending {
        my ($hash,$column) = @_;
        return sort { ($hash->{$b}{$column} || '') cmp ($hash->{$a}{$column} || '') } keys %$hash;
    }

    for (@DB) {
        $clDBID   = undef;
        ($clDBID) = $_ =~ /DB\=(\d+)/;
        $clDBID   = 0 unless defined $clDBID;
        ($CLNick)      = $_ =~ /NIK\=(\S+)/;
        ($CLIP)        = $_ =~ /IP\=(\S+)/;
        ($DNS)         = $_ =~ /DNS\=(\S+)/;
        ($CLHops)      = $_ =~ /HPS\=(\d+)/;
        ($CLHopsRead)  = $_ =~ /HPR\=(\d+)/;
        ($CLTotalTime) = $_ =~ /TTO\=(\d+)/;
        ($CLastOnline) = $_ =~ /LO\=(\d+)/;
        ($CLastChan)   = $_ =~ /LCH\=(\d+)/;
        ($UserGroups)  = $_ =~ /GPS\=(\S+)/;
        ($Punished)    = $_ =~ /PUN\=(\d+)/;
        ($Sent)        = $_ =~ /TX\=(\d+)/;
        ($Recv)        = $_ =~ /RX\=(\d+)/;
        $DBHash{$cnt}{'DBID'}       = $clDBID;
        $DBHash{$cnt}{'NICK'}       = $CLNick;
        $DBHash{$cnt}{'IP'}         = $CLIP;
        $DBHash{$cnt}{'DNS'}        = $DNS;
        $DBHash{$cnt}{'HOPS'}       = $CLHops;
        $DBHash{$cnt}{'HOPSREAD'}   = $CLHopsRead;
        $DBHash{$cnt}{'TIMEONLINE'} = $CLTotalTime;
        $DBHash{$cnt}{'LASTONLINE'} = $CLastOnline;
        $DBHash{$cnt}{'LASTCHAN'}   = $CLastChan;
        $DBHash{$cnt}{'GROUPS'}     = $UserGroups;
        $DBHash{$cnt}{'PUNISHED'}   = $Punished;
        $DBHash{$cnt}{'TX'}         = $Sent;
        $DBHash{$cnt}{'RX'}         = $Recv;
        ++$cnt;
    }

    my ($range,$start) = $request =~ /dbRange=(\d+)\+Position\=(\d+)/;
    my ($SortColumn) = $request =~ /\+SortBy\=(\S+)/;
    $SortColumn = 'DBID' unless $SortColumn;
    unless ( defined $range ) {
        $range = 50;
        $start = 0;
    }
    $cnt = 0;
    syswrite $client, <<ENDHTML;

    <div STYLE="position:absolute; top:220px;left:200px; width:700px; height:20px; border: solid 0px navy; overflow:hidden: display:block;">
        Range:<select id="dbrange" name="dbrange">
        <font size="2">

ENDHTML
    foreach my $opt (@options) {
        if ($opt == $range) {
            syswrite $client, '<option selected="selected">'.$opt.'</option>'.$nl;
        }
        else {
            syswrite $client, qq`<option onclick="javascript:MenuSwitch('db',1,'','Range=$opt+Position=$start+SortBy=$SortColumn');">`.$opt.'</option>'.$nl;
        }
    }
    syswrite $client, <<ENDHTML;

        </select>
    </div>
    <div STYLE="position:absolute; top:220px; left:300px; width:700px; height:20px; border: solid 0px navy; overflow:hidden: display:block;"
        onmouseover="this.style.cursor='pointer';"
        onmouseout="this.style.cursor='default';">

ENDHTML
    my ($lastthree,$flipped);
    my $newposition = $start + $range;
    my $oldposition = $start - $range;
    my $next  = $start + ($range * 2);
    my $next2 = $start + ($range * 3);
    my $last  = $start - $range;
    my $last2 = $start - $range * 2;
    my $last3 = $start - $range * 3;
    my $final = $Size - $range;

    if ($start >= $range) {
        syswrite $client, <<ENDHTML;
        <div style="float:left; width:auto; padding-right:5px; border: solid 0px navy;" onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=0+SortBy=$SortColumn');">
            0,
        </div>
ENDHTML
    }

    if ($last3 >= $range) {
        syswrite $client, <<ENDHTML;
        <div style="float:left; width:auto; padding-right:5px; border: solid 0px navy;" onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$last3+SortBy=$SortColumn');">
            $last2,
        </div>
ENDHTML
    }
    if ($last2 >= $range) {
        syswrite $client, <<ENDHTML;
        <div style="float:left; width:auto; padding-right:5px; border: solid 0px navy;" onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$last2+SortBy=$SortColumn');">
            $last,
        </div>
ENDHTML
    }

    syswrite $client, <<ENDHTML;
    <div style="float:left; width:auto; padding-right:5px; border: solid 0px navy;" onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$start+SortBy=$SortColumn');">
        <b>$start\-$newposition\,</b>
    </div>
    <div style="float:left; width:auto; padding-right:5px; border: solid 0px navy;" onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$newposition+SortBy=$SortColumn');">
        $next,
    </div>
ENDHTML
    if ($next2 < $Size) {
        syswrite $client, <<ENDHTML;
        <div style="float:left; width:auto; padding-right:5px; border: solid 0px navy;" onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$next+SortBy=$SortColumn');">
            $next2 ...
        </div>
ENDHTML
    }
    syswrite $client, <<ENDHTML;

    <div style="float:left; width:auto; border: solid 0px navy;" onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$final+SortBy=$SortColumn');">
        $final-$Size
    </div>

    </div>
    <div ID="Flowleft2" style="position:absolute; top:367px;left:28px;
            width:5px;z-index:18; height:100%; background-repeat:repeat-y;
            background-image: URL('/rbm_webserver/images/main_flow.png');">
    </div>
    <div ID="Flowright2" style="position:absolute; top:367px;right:28px;
            width:5px;z-index:18; height:100%; background-repeat:repeat-y;
            background-image: URL('/rbm_webserver/images/main_flow.png');">
    </div>

    <div STYLE="position:absolute; top:220px; right:190px; width:200px; height:20px; text-align:right;">
        $Size entries found.
    </div>

    <div STYLE="position:absolute; top:251px;left:51px; width:920px; height:23px; border: solid 1px navy;
        background-color:#5c778e; text-align:center;">
        <font size="3" style="arial" color="white">

ENDHTML
        $ActiveHL = $Headercolor if $SortColumn eq 'DBID';
        syswrite $client, <<ENDHTML;

        <div STYLE="position:absolute; top:0px; left:0px; width:49px; height:20px;
            padding-top: 3px; border-right: solid 1px navy; padding-top: 3px; background-color: $ActiveHL;"
            onmouseover="this.style.cursor='pointer'" onmouseout="this.style.cursor='default'"
            onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$start+SortBy=DBID'); return false;">
            DBID
        </div>

ENDHTML
       $ActiveHL = 'transparent';
       $ActiveHL = $Headercolor if $SortColumn eq 'NICK';
syswrite $client, <<ENDHTML;

        <div STYLE="position:absolute; top:0px; left:50px; width:101px; height:20px;
            padding-top: 3px; border-right: solid 1px navy; background-color: $ActiveHL;"
            onmouseover="this.style.cursor='pointer'" onmouseout="this.style.cursor='default'"
            onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$start+SortBy=NICK'); return false;">
            Name
        </div>

ENDHTML
       $ActiveHL = 'transparent';
       $ActiveHL = $Headercolor if $SortColumn eq 'IP';
syswrite $client, <<ENDHTML;

        <div STYLE="position:absolute; top:0px; left:150px; width:101px; height:20px;
            padding-top: 3px; border-right: solid 1px navy; background-color: $ActiveHL;"
            onmouseover="this.style.cursor='pointer'" onmouseout="this.style.cursor='default'"
            onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$start+SortBy=IP'); return false;">
            IP
        </div>

ENDHTML
       $ActiveHL = 'transparent';
       $ActiveHL = $Headercolor if $SortColumn eq 'DNS';
syswrite $client, <<ENDHTML;

        <div STYLE="position:absolute; top:0px; left:250px; width:101px; height:20px;
            padding-top: 3px; border-right: solid 1px navy; background-color: $ActiveHL;"
            onmouseover="this.style.cursor='pointer'" onmouseout="this.style.cursor='default'"
            onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$start+SortBy=DNS'); return false;">
            DNS
        </div>

ENDHTML
       $ActiveHL = 'transparent';
       $ActiveHL = $Headercolor if $SortColumn eq 'HOPS';
syswrite $client, <<ENDHTML;

        <div STYLE="position:absolute; top:0px; left:350px; width:61px; height:20px;
            padding-top: 3px; border-right: solid 1px navy; background-color: $ActiveHL;"
            onmouseover="this.style.cursor='pointer'" onmouseout="this.style.cursor='default'"
            onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$start+SortBy=HOPS'); return false;">
            Hops
        </div>

ENDHTML
       $ActiveHL = 'transparent';
       $ActiveHL = $Headercolor if $SortColumn eq 'HOPSREAD';
syswrite $client, <<ENDHTML;

        <div STYLE="position:absolute; top:0px; left:410px; width:76px; height:20px;
            padding-top: 3px; border-right: solid 1px navy; background-color: $ActiveHL;"
            onmouseover="this.style.cursor='pointer'" onmouseout="this.style.cursor='default'"
            onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$start+SortBy=HOPSREAD'); return false;">
            Hops Date
        </div>

ENDHTML
       $ActiveHL = 'transparent';
       $ActiveHL = $Headercolor if $SortColumn eq 'TIMEONLINE';
syswrite $client, <<ENDHTML;

        <div STYLE="position:absolute; top:0px; left:485px; width:76px; height:20px;
            padding-top: 3px; border-right: solid 1px navy; background-color: $ActiveHL;"
            onmouseover="this.style.cursor='pointer'" onmouseout="this.style.cursor='default'"
            onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$start+SortBy=TIMEONLINE'); return false;">
            Total Time
        </div>

ENDHTML
       $ActiveHL = 'transparent';
       $ActiveHL = $Headercolor if $SortColumn eq 'LASTONLINE';
syswrite $client, <<ENDHTML;

        <div STYLE="position:absolute; top:0px; left:560px; width:76px; height:20px;
            padding-top: 3px; border-right: solid 1px navy; background-color: $ActiveHL;"
            onmouseover="this.style.cursor='pointer'" onmouseout="this.style.cursor='default'"
            onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$start+SortBy=LASTONLINE'); return false;">
            Online
        </div>

ENDHTML
       $ActiveHL = 'transparent';
       $ActiveHL = $Headercolor if $SortColumn eq 'LASTCHAN';
syswrite $client, <<ENDHTML;

        <div STYLE="position:absolute; top:0px; left:635px; width:46px; height:20px;
            padding-top: 3px; border-right: solid 1px navy; background-color: $ActiveHL;"
            onmouseover="this.style.cursor='pointer'" onmouseout="this.style.cursor='default'"
            onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$start+SortBy=LASTCHAN'); return false;">
            Room
        </div>

ENDHTML
       $ActiveHL = 'transparent';
       $ActiveHL = $Headercolor if $SortColumn eq 'GROUPS';
syswrite $client, <<ENDHTML;

        <div STYLE="position:absolute; top:0px; left:680px; width:61px; height:20px;
            padding-top: 3px; border-right: solid 1px navy; background-color: $ActiveHL;"
            onmouseover="this.style.cursor='pointer'" onmouseout="this.style.cursor='default'"
            onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$start+SortBy=GROUPS'); return false;">
            Groups
        </div>

ENDHTML
       $ActiveHL = 'transparent';
       $ActiveHL = $Headercolor if $SortColumn eq 'PUNISHED';
syswrite $client, <<ENDHTML;

        <div STYLE="position:absolute; top:0px; left:740px; width:61px; height:20px;
            padding-top: 3px; border-right: solid 1px navy; background-color: $ActiveHL;"
            onmouseover="this.style.cursor='pointer'" onmouseout="this.style.cursor='default'"
            onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$start+SortBy=PUNISHED'); return false;">
            Punished
        </div>

ENDHTML
       $ActiveHL = 'transparent';
       $ActiveHL = $Headercolor if $SortColumn eq 'TX';
syswrite $client, <<ENDHTML;

        <div STYLE="position:absolute; top:0px; left:800px; width:61px; height:20px;
            padding-top: 3px; border-right: solid 1px navy; background-color: $ActiveHL;"
            onmouseover="this.style.cursor='pointer'" onmouseout="this.style.cursor='default'"
            onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$start+SortBy=TX'); return false;">
            Rx
        </div>

ENDHTML
       $ActiveHL = 'transparent';
       $ActiveHL = $Headercolor if $SortColumn eq 'TX';
syswrite $client, <<ENDHTML;

        <div STYLE="position:absolute; top:0px; left:860px; width:61px; height:20px;
            padding-top: 3px; background-color: $ActiveHL;"
            onmouseover="this.style.cursor='pointer'" onmouseout="this.style.cursor='default'"
            onclick="javascript:MenuSwitch('db',1,'','Range=$range+Position=$start+SortBy=RX'); return false;">
            Tx
        </div>

        </font>
    </div>

    <div ID="Inner2" STYLE="position:absolute; top:275px;left:31px; width:959px; border: solid 1px navy;" >
        <FORM NAME="DBTable" ID="DBTable" ACTION="DBINFO" method="POST">
        <font size="2" style="arial" color="black">
ENDHTML

    foreach my $i ( sortedHashKeysByValueDescending(\%DBHash,$SortColumn)) {
        ++$cntr;
        if ($cntr >= $start and $cntr <= ($start + $range) ) {
            $clDBID      = $DBHash{$i}{'DBID'} || '';
            $CLNick      = $DBHash{$i}{'NICK'} || '';
            $CLIP        = $DBHash{$i}{'IP'} || '';
            $DNS         = $DBHash{$i}{'DNS'} || '';
            $CLHops      = $DBHash{$i}{'HOPS'} || '';
            $CLHopsRead  = $DBHash{$i}{'HOPSREAD'} || '';
            $CLTotalTime = $DBHash{$i}{'TIMEONLINE'} || '';
            $CLastOnline = $DBHash{$i}{'LASTONLINE'} || '';
            $CLastChan   = $DBHash{$i}{'LASTCHAN'} || '';
            $UserGroups  = $DBHash{$i}{'GROUPS'} || '';
            $Punished    = $DBHash{$i}{'PUNISHED'} || '';
            $Sent        = $DBHash{$i}{'TX'} || '';
            $Recv        = $DBHash{$i}{'RX'} || '';
            syswrite $client, <<ENDHTML;

    <div STYLE="width:960px; height:20px; text-align:left; background-color: #f6f7fa;">
        <div STYLE="position:absolute; left:0px; width:17px; height:20px; border-right: solid 1px navy; overflow:hidden; padding-left:2px;">
            $i
        </div>

        <div STYLE="position:absolute; left:19px; width:50px; height:20px; border-right: solid 1px navy; overflow:hidden;">
            $clDBID
        </div>
        <div STYLE="position:absolute; left:71px; width:100px; height:20px; border-right: solid 1px navy; overflow:hidden;">
            $CLNick
        </div>
        <div STYLE="position:absolute; left:171px; width:100px; height:20px; border-right: solid 1px navy; overflow:hidden;">
            $CLIP
        </div>
        <div STYLE="position:absolute; left:271px; width:100px; height:20px; border-right: solid 1px navy; overflow:hidden;">
            $DNS
        </div>
        <div STYLE="position:absolute; left:371px; width:60px; height:20px; border-right: solid 1px navy; overflow:hidden;">
            $CLHops
        </div>
        <div STYLE="position:absolute; left:431px; width:75px; height:20px; border-right: solid 1px navy; overflow:hidden;">
            $CLHopsRead
        </div>
        <div STYLE="position:absolute; left:506px; width:75px; height:20px; border-right: solid 1px navy; overflow:hidden;">
            $CLTotalTime
        </div>
        <div STYLE="position:absolute; left:581px; width:75px; height:20px; border-right: solid 1px navy; overflow:hidden;">
            $CLastOnline
        </div>
        <div STYLE="position:absolute; left:656px; width:45px; height:20px; border-right: solid 1px navy; overflow:hidden;">
            $CLastChan
        </div>
        <div STYLE="position:absolute; left:701px; width:60px; height:20px; border-right: solid 1px navy; overflow:hidden;">
            $UserGroups
        </div>
        <div STYLE="position:absolute; left:761px; width:60px; height:20px; border-right: solid 1px navy; overflow:hidden;">
            $Punished
        </div>
        <div STYLE="position:absolute; left:821px; width:60px; height:20px; border-right: solid 1px navy; overflow:hidden;">
            $Sent
        </div>
        <div STYLE="position:absolute; left:881px; width:60px; height:20px; border-right: solid 1px navy; overflow:hidden;">
            $Recv
        </div>
        <div STYLE="position:absolute; left:940px; width:20px; height:20px; overflow:hidden;">
            <input type="checkbox" name="$clDBID" value="PurgeSingle">
        </div>
    </div>
ENDHTML
        }
    }

    syswrite $client, <<ENDHTML;
        </font>
        <div STYLE="position:absolute;bottom:-25px;right:3px; width:100px;
            height:20px; border: solid 0px navy; overflow:hidden: display:block;
            text-align:right;"
            onmouseover="this.style.cursor='pointer'"
            onmouseout="this.style.cursor='default'"
            onclick="javascript:form_success_client('DBTable','ajaxbodywide',''); javascript:MenuSwitch('db',1,'','Range=$range+Position=$start'); return false;">

            Delete
        </div>

        </form>
    </div>
ENDHTML
}

sub Rbm_QueryPost {
    my ($client,$request,$websock) = @_;
  #  $request =~ s/\w+\=\w+\%20\w+\=/\\s/gi;
    $request =~ s/\%20/ /gi;
    syswrite $websock, $request.$nl;
}

sub Rbm_Query {
    my ($client,$request) = @_;

    syswrite $client, <<ENDHTML;
    <div style="position:absolute; top:580px;left:-15px;
            width:674px;z-index:18; height:5px; background-repeat:repeat-x;
            background-image: URL('/rbm_webserver/images/main_flow_x.png');">
    </div>
    <div style="position:absolute; top:539px; right:-20px;
            width:5px; z-index:18; height:45px; background-repeat:repeat-y;
            background-image: URL('/rbm_webserver/images/main_flow.png');">
    </div>

    <div ID="ReceiveQuery" STYLE="position:absolute; top:16px; left:50%; width:646px;
        height:531px; margin-left:-326px; border: solid 1px navy; display:block;
        overflow-y:auto; background:#e6ecf9; padding: 3px;">
    </div>

    <div ID="SendQuery" STYLE="position:absolute; bottom:21px; left:50%; width:652px;
        height:23px; margin-left:-326px; border: solid 1px navy; display:block;
        overflow:hidden;">

        <TEXTAREA ID="QueryPost" STYLE="overflow:hidden; overflow-y:auto;
            background-color:#efeffa; width:647px; height:18px; resize:none;"
            MAXLENGTH="4000"
            onclick="if (document.getElementById('QueryPost').value === 'Type <help> for more TS3 query commands.') { document.getElementById('QueryPost').value=''; };"
            ONKEYDOWN="if ((event.which && event.which === 13) || (event.keyCode && event.keyCode === 13)) {javascript:PostQuery();
            javascript:setTimeout('QueryTS3();', 10); return false;} else return true;">Type <help> for more TS3 query commands.</TEXTAREA>

ENDHTML
}

sub Rbm_Querydata {
    my ($client,$request) = @_;
    my $file = './rbm_stored/rbm_query.cf';
    open my $QueryDB, "<",$file or die 'Error '.$!;
    while (my $data = <$QueryDB> ) {
        syswrite $client, '<font size="2">'.$data.'</font>'.$nl;
    }
    close $QueryDB;
}

sub Rbm_CleanFORM {
    my $request = shift;
    my %FORM = ();
    $request =~ s/^.+?  //i;

    my @Tmp = split /\&/, $request;

    foreach my $raw (@Tmp) {
        my ($Name,$Value) = $raw =~ /(\S+)=(.*?)$/;
        next unless $Name;
        $Name =~ s/^\s+|\s+$//gi;
        $Value =~ s/^\s+|\s+$//gi;
   #     $Value =~ s/ [\-]+\d+[\-]+|^\s+|\s+$//gi;
        $FORM{$Name} = $Value;
    }
    return \%FORM;
}

sub Rbm_Grid1 {
    my $request = shift;

    if ( $request =~ /\?Connect Mod/i ) {
        &rbm_parent::Rbm_ParentCaching('StartSocket');
    }
    elsif ( $request =~ /\?Disconnect Mod/i ) {
        &rbm_parent::Rbm_ParentCaching('StopSocket');
    }
    elsif ( $request =~ /\?Reconnect Mod/i ) {
        &rbm_parent::Rbm_ParentCaching('Reconnect');
    }
    elsif ( $request =~ /\?Reboot Mod/i ) {
        &rbm_parent::Rbm_ParentCaching('Reload');
    }
}

1;
