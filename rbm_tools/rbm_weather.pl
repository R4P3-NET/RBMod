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
use Weather::Underground;
use Time::HiRes qw ( sleep );

my ($CCode,$DBID,$CLID,$CLIP,$OSType,$City,$Region,$Country,$cels,$Pause)
    = @ARGV;
my ($key,$value,$NoIcon,$newValue,$oldValue,$arrayref,$Latitude,$Longitude,$gi,
    $Conditions,$Celsius,$Fahrenheit);
$arrayref = &Rbm_WeatherLookup($City,$Region,$Country);

if ($arrayref) {
    foreach (@$arrayref) {
        while ( ($key, $value) = each %{$_} ) {
            next unless $key && $value;
            if ( $key eq 'conditions' ) {
                $Conditions = $value;
                $Conditions =~ s/ /\\s/go;
            }
            elsif ( $key eq 'celsius' ) {
                $Celsius = $value;
            }
            elsif ( $key eq 'fahrenheit' ) {
                $Fahrenheit = $value;
            }
        }
    }
}

if (!defined $Celsius and !defined $Fahrenheit and (!defined $cels or $cels !~ /\S+/o)) {
    my $NewIP = $CLIP;
    my ($i,$data,$key,$value,$OldIP,$line,$RegionNEW,$CityNEW,$CountryNEW,
        $dupe,$dupe2,$dupe3) = 0;
    for ($i=0; $i <= 255; $i++) {
        ($dupe) = $NewIP =~ m/\d+.\d+.(\d+).\d+$/;
        $dupe = $dupe - $i;
        if ($dupe <= 0) {
            $dupe = 0;
            ($dupe2) = $NewIP =~ m/\d+.(\d+).\d+.\d+$/;
            --$dupe2;
            --$dupe2;
            $dupe2 = 0 if $dupe2 <= 0;
            if ($dupe2 <= 0) {
                $dupe2 = 0;
                ($dupe3) = $NewIP =~ m/(\d+).\d+.\d+.\d+$/;
                --$dupe3;
                $dupe3 = 0 if $dupe3 <= 0;
                $NewIP =~ s/\d+.(\d+.\d+.\d+)$/$dupe3\.0\.0\.0/;
            }
            $NewIP =~ s/(\d+.)\d+.(\d+.\d+)$/$1$dupe2\.$2/;
        }
        $NewIP =~ s/(\d+.\d+.)\d+.\d+$/$1$dupe\.0/;
        exit 0 if $OldIP eq $NewIP;
        $OldIP = $NewIP;
        ($data) = `$^X ./rbm_tools/rbm_geo.pl $NewIP $DBID $CLID $CCode $NewIP $NewIP $NewIP`;
        ($RegionNEW,$CityNEW,$CountryNEW) = $data =~ /REGION=(\S+) CITY=(\S+) CODE=(\S+)/o;
        sleep 3 and next if $CityNEW eq $City;
        sleep $Pause if $Pause;
        $arrayref = &Rbm_WeatherLookup($CityNEW,$RegionNEW,$Country);
        sleep 3 and next if !defined $arrayref;
        $City =~ s/ /\\s/g;
        $Region =~ s/ /\\s/g;

        foreach (@$arrayref) {
            while ( ($key, $value) = each %{$_} ) {
                next unless $key && $value;
                if ( $key eq 'conditions' ) {
                    $Conditions = $value;
                    $Conditions =~ s/ /\\s/go;
                }
                elsif ( $key eq 'celsius' ) {
                    $Celsius = $value;
                }
                elsif ( $key eq 'fahrenheit' ) {
                    $Fahrenheit = $value;
                }
            }
        }
        open(my $CACHE, ">>",'rbm_stored/rbm_cache.cf') or die $!;
        flock($CACHE, 2);
        $line = 'DBID='.$DBID.' CLID='.$CLID.' REGION='.$RegionNEW
                .'-ALT CITY='.$CityNEW.'-ALT CODE='.$CCode.' LONG=0 LAT=0 IDLETIME=0 CHANID=0|';
        syswrite $CACHE, $line;
        $line = 'DBID='.$DBID.' CLID='.$CLID.' COND='.$Conditions
            .' CELS='.$Celsius.' FAHR='.$Fahrenheit.' CODE='.$CCode.'|';
        syswrite $CACHE, $line;
        flock($CACHE, 8);
        close $CACHE;
        last;
    }
}
elsif (defined $Celsius or defined $Fahrenheit and (!defined $cels or $cels !~ /\S+/o)) {
    $Fahrenheit = 'Null' unless $Fahrenheit;
    $Celsius = 'Null' unless $Celsius;
    open(my $CACHE, ">>",'rbm_stored/rbm_cache.cf') or die $!;
    flock($CACHE, 2);
    my $line = 'DBID='.$DBID.' CLID='.$CLID.' COND='.$Conditions
        .' CELS='.$Celsius.' FAHR='.$Fahrenheit.' CODE='.$CCode.'|';
    syswrite $CACHE, $line;
    flock($CACHE, 8);
    close $CACHE;
}
else {
    foreach (@$arrayref) {
        while ( ($key, $value) = each %{$_} ) {
            next unless $key and $value;
            if ( $key eq 'celsius' or $key eq 'fahrenheit' ) {
                ($newValue) = $value =~ /^(\d+)/;
                if ($key eq 'fahrenheit') {
                    $newValue = sprintf "%.0f", ($newValue - 32) * 5/9;
                }
                if ($cels != $newValue ) {
                    open(my $CACHE, ">>",'rbm_stored/rbm_cache.cf') or die $!;
                    flock($CACHE, 2);
                    syswrite $CACHE, 'DBID='.$DBID.' CLID='.$CLID
                            .' READCELSIUS='.$newValue.'|';
                    flock($CACHE, 8);
                    close $CACHE;
                }
                last;
            }
        }
    }
}

exit 0;

sub Rbm_WeatherLookup {
    my ($City,$Region,$Country) = @_;
    my $arrayrefy;
    $City = '' unless $City;
    $City =~ s/\\s/ /go if $City;
    $Country =~ s/\\s/ /go;
    $Region =~ s/\\s/ /go;
    close STDERR;
    my $weather5 = Weather::Underground->new(
            place => $City.', '.$Country, timeout => 2) or die $@;
    $arrayrefy = $weather5->get_weather();
    if (!$arrayrefy) {
        my $weather3 = Weather::Underground->new(
                place => $City.', '.$Region.', '.$Country, timeout => 2)
                or die $@;
        $arrayrefy = $weather3->get_weather();
    }
    if (!$arrayrefy) {
        my $weather1 = Weather::Underground->new(
                place => $City, timeout => 1 ) or die $@;
        $arrayrefy = $weather1->get_weather();
    }
    if (!$arrayrefy) {
        my $weather2 = Weather::Underground->new(
                place => $City.', '.$Region, timeout => 1) or die $@;
        $arrayrefy = $weather2->get_weather();
    }
    if (!$arrayrefy) {
        my $weather4 = Weather::Underground->new(
                place => $Region.', '.$Country, timeout => 1) or die $@;
        $arrayrefy = $weather4->get_weather();
    }
    open STDERR;
    return $arrayrefy if $arrayrefy;
}

