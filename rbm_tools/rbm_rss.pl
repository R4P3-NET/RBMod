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
# |                                  v3.2.4                                    |
# `============================================================================`
use 5.10.0;
use strict;
use warnings;
use File::Copy;
use Encode;
use LWP::Simple;
use XML::Parser;
use Time::HiRes qw ( sleep );

my ($SET_RSSURL) = @ARGV;
$SET_RSSURL = 'http://'.$SET_RSSURL unless $SET_RSSURL =~ /http\:\/\//oi;
$SET_RSSURL = &get($SET_RSSURL) or die $!;

my $parser = new XML::Parser (
        ErrorContext => 2,
        Handlers => {   # Creates our parser object
            Start   => \&hdl_start,
            End     => \&hdl_end,
            Char    => \&hdl_char,
            Default => \&hdl_def,
});
my (@Old,$xmline,@array,$linefeed,$CLIDs,$message);
if ( -e 'rbm_stored/rbm_rssold.cf' ) {
    open(my $OLDFEED, "<",'rbm_stored/rbm_rssold.cf');
    @Old = <$OLDFEED>;
    close $OLDFEED;
}
unlink('rbm_stored/rbm_rssnew.cf');
$parser->parse($SET_RSSURL);
copy('rbm_stored/rbm_rssnew.cf','rbm_stored/rbm_rssold.cf')
        if -e 'rbm_stored/rbm_rssnew.cf';
open(my $NEWFEED, "<",'rbm_stored/rbm_rssnew.cf');
my @New = <$NEWFEED> if $NEWFEED;
close $NEWFEED;
my %Old = map {$_, 1} @Old;
my @difference = grep { !$Old{$_} } @New;
exit 0 if scalar(@difference) < 2;
$xmline = join '', @difference;
$xmline = encode("utf8", $xmline);
$xmline =~ s/\|/\\p/go;
$xmline =~ s/\n/\\n/go;
open(my $CACHE, ">>",'rbm_stored/rbm_cache.cf') or die "ERROR\t- RSS   \t- Couldn\'t Load rbm_cache.cf: ".$!;
flock($CACHE, 2);
print $CACHE 'GRSS='.$xmline.'|';
flock($CACHE, 8);
close $CACHE;


sub hdl_start {
    my ($p, $elt, %atts) = @_;
    $atts{'_str'} = '';
    $message = \%atts;
}

sub hdl_end {
    my ($p, $elt) = @_;
    format_message($message) if defined $message && $message->{'_str'} =~ /\S/o;
}

sub hdl_char {
    my ($p, $str) = @_;
    $message->{'_str'} .= $str;
}

sub hdl_def {}

sub format_message {
    my $atts = shift;
    $atts->{'_str'} =~ s/\n//og;
    $atts->{'_str'} =~ s`\<a href\=\"(.*?)\">(.*?)<\/a>`\[URL=$1\]$2\[\/URL\]\\s`gi;
    $atts->{'_str'} =~ s/<.*?>|\s{2,}|\"//go;
    $atts->{'_str'} =~ s/\|/\n/go;
    $atts->{'_str'} =~ s/^http\:\/\/\S+/\n/go;
    $atts->{'_str'} =~ s/(\-\d{3,})/$1\\s\-\\s/go;
    $atts->{'_str'} =~ s/postedon/posted\\son/goi;
    $atts->{'_str'} =~ s/\&amp\;/\&/go;
    $atts->{'_str'} =~ s/\&\#146\;/\'/go;
    $atts->{'_str'} =~ s/\&\#147\;/\"/go;
    $atts->{'_str'} =~ s/\&\#160\;//go;
    $atts->{'_str'} =~ s/\&\#163\;/\£/go;
    $atts->{'_str'} =~ s/(\w+\, \d+ \w+ \d+ \d+.*?\-\d+)/\[B\]$1\[\/B\]/go;
#    $atts->{'_str'} =~ s/[^[:ascii:]]+//go;  # get rid of non-ASCII characters
    my $line = encode("utf8", $atts->{'_str'});
    open(my $CACHE, ">>",'rbm_stored/rbm_rssnew.cf') or return;
    flock($CACHE, 2);
    syswrite $CACHE, $line;
    flock($CACHE, 8);
    close $CACHE;
    undef $message;
}
