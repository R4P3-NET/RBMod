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
#            This product includes GeoLite data created by MaxMind,
#                    available from http://www.maxmind.com

use 5.10.0;
use strict;
use warnings;
use Geo::IP::PurePerl;
my $gi = Geo::IP::PurePerl->open('./GeoLiteCity.dat');
#my $gi = Geo::IP::PurePerl->open('./GeoLiteCity.dat',GEOIP_MEMORY_CACHE);
my ($CLIP,$DBID,$CLID,$CCode,$pingable,$pingable2,$pingable3,$Idletime,$ChanID)
    = @ARGV;
my ($City,$Region,$CountryName,$Latitude,$Longitude)
        = &Rbm_CountryRegionCity($CCode,$CLID,$CLIP,$pingable,$pingable2,$pingable3);
if (!$Idletime) {
    say 'DBID='.$DBID.' CLID='.$CLID.' REGION='.$Region.' CITY='.$City.' CODE='.$CCode;
    exit 0;
}
$City =~ s/ /\\s/g;
$Region =~ s/ /\\s/g;
open(my $CACHE, ">>",'rbm_stored/rbm_cache.cf') or die $!;
flock($CACHE, 2);
my $line = 'DBID='.$DBID.' CLID='.$CLID.' REGION='.$Region
        .' CITY='.$City.' CODE='.$CCode.' LONG='.$Longitude
        .' LAT='.$Latitude.' IDLETIME='.$Idletime
        .' CHANID='.$ChanID.'|';
syswrite $CACHE, $line;
flock($CACHE, 8);
close $CACHE;
exit 0;

sub Rbm_CountryRegionCity {
    my ($CCode,$CLID,$CLIP,$pingable,$pingable2,$pingable3) = @_;
    my ($code2,$code3,$country_name,$Region,$City,$PostalCode,$Latitude,
        $Longitude,$Country,$NewIP);
    my $CCodeNames_ref = &Rbm_CCodes;
    close STDERR;
    ($code2,$code3,$country_name,$Region,$City,$PostalCode,$Latitude,
            $Longitude) = $gi->get_city_record( $CLIP )
    or (($code2,$code3,$country_name,$Region,$City,$PostalCode,$Latitude,
            $Longitude) = $gi->get_city_record( $pingable ))
    or (($code2,$code3,$country_name,$Region,$City,$PostalCode,$Latitude,
            $Longitude) = $gi->get_city_record( $pingable2 ))
    or (($code2,$code3,$country_name,$Region,$City,$PostalCode,$Latitude,
            $Longitude) = $gi->get_city_record( $pingable3 ));
    open STDERR;
    $Region =~ s/\d+$//go if $Region;
    $Region = 'Null' unless $Region =~ /\w+/o;
    $City = 'Null' unless $City =~ /\w+/o;
    $Latitude = 'Null' unless $Latitude =~ /\d/o;
    $Longitude = 'Null' unless $Longitude =~ /\d/o;
    $CCode = $code2 if !$CCode or $CCode !~ /\w+/o;
    $Country = $CCodeNames_ref->{$CCode}{Name};
    $Country = 'Null' unless $Country;
    $Region =~ s/ /\\s/go if $Region;
    $City =~ s/ /\\s/go if $City;
    $Country =~ s/ /\\s/go if $Country;
    return ($City,$Region,$Country,$Latitude,$Longitude);
}

sub Rbm_CCodes {
    my %CCodes = (
        AD => { Name => 'Andorra',                          Icon => 495225700 },
        AE => { Name => 'United Arab Emirates',             Icon => 729710808 },
        AF => { Name => 'Afghanistan',                      Icon => 227256470 },
        AG => { Name => 'Antigua & Barbuda',                Icon => 264231074 },
        AI => { Name => 'Anguilla',                         Icon => 271412934 },
        AL => { Name => 'Albania',                          Icon => 266561922 },
        AM => { Name => 'Armenia',                          Icon => 209030974 },
        AN => { Name => 'Netherlands Antilles',             Icon => 399321349 },
        AO => { Name => 'Angola',                           Icon => 292008668 },
        AQ => { Name => 'Antarctica',                       Icon => 0         },
        AR => { Name => 'Argentina',                        Icon => 164966870 },
        AS => { Name => 'American Samoa',                   Icon => 234363683 },
        AT => { Name => 'Austria',                          Icon => 241702449 },
        AU => { Name => 'Australia',                        Icon => 308363326 },
        AW => { Name => 'Aruba',                            Icon => 477279392 },
        AX => { Name => 'Aland Islands',                    Icon => 137399114 },
        AZ => { Name => 'Azerbaijan',                       Icon => 252860616 },
        BA => { Name => 'Bosnia and Herzegovina',           Icon => 542752765 },
        BB => { Name => 'Barbados',                         Icon => 37908925  },
        BD => { Name => 'Bangladesh',                       Icon => 156886803 },
        BE => { Name => 'Belgium',                          Icon => 377863488 },
        BF => { Name => 'Burkina Faso',                     Icon => 900747833 },
        BG => { Name => 'Bulgaria',                         Icon => 279215256 },
        BH => { Name => 'Bahrain',                          Icon => 196449300 },
        BI => { Name => 'Burundi',                          Icon => 675039630 },
        BJ => { Name => 'Benin',                            Icon => 192584657 },
        BM => { Name => 'Bermuda',                          Icon => 299152877 },
        BN => { Name => 'Brunei Darussalam',                Icon => 370135850 },
        BO => { Name => 'Bolivia',                          Icon => 421050301 },
        BR => { Name => 'Brazil',                           Icon => 667719659 },
        BS => { Name => 'Bahamas',                          Icon => 160097176 },
        BT => { Name => 'Bhutan',                           Icon => 150139351 },
        BV => { Name => 'Bouvet Island',                    Icon => 276801542 },
        BW => { Name => 'Botswana',                         Icon => 289315615 },
        BY => { Name => 'Belarus',                          Icon => 818015526 },
        BZ => { Name => 'Belize',                           Icon => 307384457 },
        CA => { Name => 'Canada',                           Icon => 273624138 },
        CC => { Name => 'Cocos (Keeling) Islands',          Icon => 397073152 },
        CD => { Name => 'Congo, Democratic Republic',       Icon => 223944790 },
        CF => { Name => 'Central African Republic',         Icon => 345295982 },
        CG => { Name => 'Congo',                            Icon => 348023176 },
        CH => { Name => 'Switzerland',                      Icon => 234424913 },
        CI => { Name => 'Cote D\'Ivoire (Ivory Coast)',     Icon => 889784898 },
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
        FK => { Name => 'Falkland Islands (Malvinas)',      Icon => 105351300 },
        FM => { Name => 'Micronesia',                       Icon => 266804568 },
        FO => { Name => 'Faroe Islands',                    Icon => 505043869 },
        FR => { Name => 'France',                           Icon => 280123101 },
        FX => { Name => 'France, Metropolitan',             Icon => 280123101 },
        GA => { Name => 'Gabon',                            Icon => 208439829 },
        GB => { Name => 'Great Britain (UK)',               Icon => 696821670 },
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
        GS => { Name => 'S. Georgia and S. Sandwich Isls.', Icon => 667333692 },
        GT => { Name => 'Guatemala',                        Icon => 890260105 },
        GU => { Name => 'Guam',                             Icon => 146981379 },
        GW => { Name => 'Guinea-Bissau',                    Icon => 369980747 },
        GY => { Name => 'Guyana',                           Icon => 262529908 },
        HK => { Name => 'Hong Kong',                        Icon => 316610180 },
        HM => { Name => 'Heard and McDonald Islands',       Icon => 308363326 },
        HN => { Name => 'Honduras',                         Icon => 383796375 },
        HR => { Name => 'Croatia (Hrvatska)',               Icon => 321577995 },
        HT => { Name => 'Haiti',                            Icon => 411225277 },
        HU => { Name => 'Hungary',                          Icon => 220225951 },
        ID => { Name => 'Indonesia',                        Icon => 428536670 },
        IE => { Name => 'Ireland',                          Icon => 251224607 },
        IL => { Name => 'Israel',                           Icon => 102929215 },
        IM => { Name => 'Isle of Man',                      Icon => 0 },
        IN => { Name => 'India',                            Icon => 241370755 },
        IO => { Name => 'British Indian Ocean Territory',   Icon => 387875496 },
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
        KN => { Name => 'Saint Kitts and Nevis',            Icon => 234004114 },
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
        MK => { Name => 'F.Y.R.O.M. (Macedonia)',           Icon => 397399389 },
        ML => { Name => 'Mali',                             Icon => 223164354 },
        MM => { Name => 'Myanmar',                          Icon => 393047576 },
        MN => { Name => 'Mongolia',                         Icon => 324387709 },
        MO => { Name => 'Macau',                            Icon => 869550515 },
        MP => { Name => 'Northern Mariana Islands',         Icon => 296549866 },
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
        NZ => { Name => 'New Zealand (Aotearoa)',           Icon => 390246034 },
        OM => { Name => 'Oman',                             Icon => 283441326 },
        PA => { Name => 'Panama',                           Icon => 376107579 },
        PE => { Name => 'Peru',                             Icon => 161029779 },
        PF => { Name => 'French Polynesia',                 Icon => 192958478 },
        PG => { Name => 'Papua New Guinea',                 Icon => 338306111 },
        PH => { Name => 'Philippines',                      Icon => 405405012 },
        PK => { Name => 'Pakistan',                         Icon => 340372507 },
        PL => { Name => 'Poland',                           Icon => 285096763 },
        PM => { Name => 'St. Pierre and Miquelon',          Icon => 851536736 },
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
        SJ => { Name => 'Svalbard & Jan Mayen Isls',        Icon => 276801542 },
        SK => { Name => 'Slovak Republic',                  Icon => 625492271 },
        SL => { Name => 'Sierra Leone',                     Icon => 175244219 },
        SM => { Name => 'San Marino',                       Icon => 624782645 },
        SN => { Name => 'Senegal',                          Icon => 261716386 },
        SO => { Name => 'Somalia',                          Icon => 406802917 },
        SR => { Name => 'Suriname',                         Icon => 171880247 },
        SS => { Name => 'South Sudan',                      Icon => 0 },
        ST => { Name => 'Sao Tome and Principe',            Icon => 292650062 },
        SU => { Name => 'USSR (former)',                    Icon => 0 },
        SV => { Name => 'El Salvador',                      Icon => 295264596 },
        SY => { Name => 'Syria',                            Icon => 409175148 },
        SZ => { Name => 'Swaziland',                        Icon => 179327845 },
        TC => { Name => 'Turks and Caicos Islands',         Icon => 967372232 },
        TD => { Name => 'Chad',                             Icon => 362531745 },
        TF => { Name => 'French Southern Territories',      Icon => 428465066 },
        TG => { Name => 'Togo',                             Icon => 348006257 },
        TH => { Name => 'Thailand',                         Icon => 53960251  },
        TJ => { Name => 'Tajikistan',                       Icon => 135488456 },
        TK => { Name => 'Tokelau',                          Icon => 110845999 },
        TM => { Name => 'Turkmenistan',                     Icon => 262461334 },
        TN => { Name => 'Tunisia',                          Icon => 741545167 },
        TO => { Name => 'Tonga',                            Icon => 632716282 },
        TP => { Name => 'East Timor',                       Icon => 0 },
        TR => { Name => 'Turkey',                           Icon => 370607123 },
        TT => { Name => 'Trinidad and Tobago',              Icon => 309560377 },
        TV => { Name => 'Tuvalu',                           Icon => 399674305 },
        TW => { Name => 'Taiwan',                           Icon => 104500121 },
        TZ => { Name => 'Tanzania',                         Icon => 325886174 },
        UA => { Name => 'Ukraine',                          Icon => 271350152 },
        UG => { Name => 'Uganda',                           Icon => 179890634 },
        UK => { Name => 'United Kingdom',                   Icon => 696821670 },
        UM => { Name => 'U.S. Minor Outlying Islands',      Icon => 136140099 },
        US => { Name => 'United States of America',         Icon => 266370988 },
        UY => { Name => 'Uruguay',                          Icon => 25316601 },
        UZ => { Name => 'Uzbekistan',                       Icon => 176242270 },
        VA => { Name => 'Vatican City State',               Icon => 730653405 },
        VC => { Name => 'St. Vincent & the Grenadines',     Icon => 243400126 },
        VE => { Name => 'Venezuela',                        Icon => 175416143 },
        VG => { Name => 'British Virgin Islands',           Icon => 149703715 },
        VI => { Name => 'Virgin Islands (U.S.)',            Icon => 218670502 },
        VN => { Name => 'Viet Nam',                         Icon => 219228651 },
        VU => { Name => 'Vanuatu',                          Icon => 109945284 },
        WF => { Name => 'Wallis and Futuna Islands',        Icon => 317846348 },
        WS => { Name => 'Samoa',                            Icon => 365616972 },
        XK => { Name => 'Kosovo',                           Icon => 0 },
        YE => { Name => 'Yemen',                            Icon => 245410384 },
        YT => { Name => 'Mayotte',                          Icon => 100073622 },
        YU => { Name => 'Serbia & Montenegro',              Icon => 0 },
        ZA => { Name => 'South Africa',                     Icon => 389572971 },
        ZM => { Name => 'Zambia',                           Icon => 202365049 },
        ZR => { Name => 'CD Congo, Democratic Republic',    Icon => 0 },
        ZW => { Name => 'Zimbabwe',                         Icon => 420692818 }
    );
    return \%CCodes;
}

exit 0;
