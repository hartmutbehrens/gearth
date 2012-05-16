#!/usr/bin/perl -w
#!/Perl/bin/Perl.exe -w

# richard.ivanov@alcatel.co.za

use strict;
use warnings;
use DBI;
use Math::Trig;

my $dbh = connect_db();
die "Could not connect alcatelRSA database! Please check settings in connect_db() subroutine!\n" unless defined $dbh;


use constant DEBUG => 0;			# 1 = enabled;
use constant VERBOSE => 0;			# 1 = enabled;
use constant MAKE_MYPLACES => 0;	# 1 = enabled;
use constant TRANSFORM => 0;	# 1 = enabled;

my $OutFile = '/var/www/html/VodacomSites.kml';
if (MAKE_MYPLACES) {
	$OutFile = '/var/tools/radar/etc/myplaces.kml';
}
my $count = 0;
my $IconDir = "./icons";
my $cgi = "http://nq-radar.vodacom.co.za/cgi-bin/g.pl";
my $tname = "CELLPOSITIONS_GSM";
my @Azimuths = (0,45,90,135,180,225,270,315);
my $Width = 45;
my %Regions = (
	"CEN"=>"Central",
	"WES"=>"Western",
	"LES"=>"Lesotho",
	"KZN"=>"Kwa-Zulu Natal",
	"SGA"=>"Southern Gauteng A",
	"SGS"=>"Southern Gauteng S",
	"SGC"=>"Southern Gauteng C",
	"NGA"=>"Northern Gauteng",
	"LIM"=>"Limpopo",
	"MPU"=>"Mpumalanga",
	"EAS"=>"Eastern"
	);
	
my %colors = (
	"CEN"=>"ff0000ff",
	"WES"=>"ff00ff00",
	"LES"=>"ff000000",
	"KZN"=>"ff00ffff",
	"SGA"=>"ffff0000",
	"SGS"=>"ffff00ff",
	"SGC"=>"ffffff00",
	"NGA"=>"ffffffff",
	"LIM"=>"ff001122",
	"MPU"=>"ff112233",
	"EAS"=>"ff445566"
);

# transformation support
my $degrees_per_radian = 180/pi;
my %Ellipsoids = (
    'WGS84'              => [ 6378137.0,   298.257223563   ],
    'AIRY'               => [ 6377563.396, 299.3249646     ],
    'AIRY-MODIFIED'      => [ 6377340.189, 299.3249646     ],
    'AUSTRALIAN'         => [ 6378160.0,   298.25          ],
    'BESSEL-1841'        => [ 6377397.155, 299.1528128     ],
    'CLARKE-1880'        => [ 6378249.145, 293.465         ],
    'EVEREST-1830'       => [ 6377276.345, 300.8017        ],
    'EVEREST-MODIFIED'   => [ 6377304.063, 300.8017        ],
    'FISHER-1960'        => [ 6378166.0,   298.3           ],
    'FISHER-1968'        => [ 6378150.0,   298.3           ],
    'GRS80'              => [ 6378137.0,   298.25722210088 ],
    'HOUGH-1956'         => [ 6378270.0,   297.0           ],
    'HAYFORD'            => [ 6378388.0,   297.0           ],
    'IAU76'              => [ 6378140.0,   298.257         ],
    'KRASSOVSKY-1938'    => [ 6378245.0,   298.3           ],
    'NAD27'              => [ 6378206.4,   294.9786982138  ],
    'NWL-9D'             => [ 6378145.0,   298.25          ],
    'SOUTHAMERICAN-1969' => [ 6378160.0,   298.25          ],
    'SOVIET-1985'        => [ 6378136.0,   298.257         ],
    'WGS72'              => [ 6378135.0,   298.26          ],
);

my %DatumDeltaWGS84 = (
    'CAPE'        => [ -136, -108, -292 ],
    'NAD27_CONUS' => [ -8, 160, 176 ],
);


if ($^O =~ /mswin/i) {
	$OutFile = './VodacomSites.kml';
	if (MAKE_MYPLACES) {
		$OutFile = './myplaces.kml';
	}
}

main ();
exit;

sub main {
	
	my $flattening = ( 1.0 / $Ellipsoids{'CLARKE-1880'}[1]);
	my $equatorial = $Ellipsoids{'CLARKE-1880'}[0];	# equatorial = major
  my $polar = $equatorial * ( 1.0  - $flattening );
  my $eccentricity = sqrt(2.0 * $flattening - ( $flattening * $flattening ) );
  my $eccentricity_squared = 2.0 * $flattening - ( $flattening * $flattening );
    
	my $to_flattening = ( 1.0 / $Ellipsoids{'WGS84'}[1]);
	my $to_equatorial = $Ellipsoids{'WGS84'}[0];	# equatorial = major

	my @tables = @{$dbh->selectcol_arrayref("show tables")};

	open OUTFILE, ">$OutFile" or die("Cannot open $OutFile :$!");
	
	#HEADER
	print OUTFILE <<TILLHDR;
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://earth.google.com/kml/2.0">
TILLHDR

	if (MAKE_MYPLACES) {
		print OUTFILE <<TILLMPL1;
<Document>
 <Folder>
  <name>My Places</name>
  <open>1</open>
TILLMPL1
	}

	my (undef,undef,undef,$mday,$mon,$year,undef,undef,undef) = localtime(time);
	my $tdstr = sprintf ("%04d-%02d-%02d", $year+1900, $mon+1, $mday);

	print OUTFILE <<TILLHERE;
 <Document>
  <name>Vodacom 2G Sites $tdstr</name>
  <visibility>1</visibility>
TILLHERE

	# MAKE ALL ICON STYLES
	opendir(DIR, $IconDir) or die "can't opendir $IconDir: $!";
	my @iconfiles = grep { /png$/ && -f "$IconDir/$_" } readdir(DIR);
	closedir DIR;
for my $region (keys %colors) {
	for my $icon (@iconfiles) {
		$icon =~ s/\.png$//;
		print OUTFILE <<TILLENDICON;
  <Style id="n$icon$region">
   <IconStyle>
   <color>$colors{$region}</color>
    <Icon><href>/Program Files/VodacomSiteDB/$icon.png</href></Icon>
   </IconStyle>
   <LabelStyle>
	<color>7dffffff</color>
   </LabelStyle>
  </Style>
  <Style id="h$icon$region">
   <IconStyle>
  	<scale>1.5</scale>
  	<color>$colors{$region}</color>
    <Icon><href>/Program Files/VodacomSiteDB/$icon.png</href></Icon>
   </IconStyle>
   <LabelStyle>
	<color>ffffffff</color>
   </LabelStyle>
  </Style>
  <StyleMap id="$icon">
   <Pair>
    <key>normal</key>
    <styleUrl>#n$icon$region</styleUrl>
   </Pair>
   <Pair>
    <key>highlight</key>
    <styleUrl>#h$icon$region</styleUrl>
   </Pair>
  </StyleMap>
TILLENDICON
		
	}
}

	for my $region (sort {$Regions{$a} cmp $Regions{$b} } keys %Regions) {

		my ($sth,$sth2,$sth3);
		my %sites = ();
	
		# poll DB
		$sth3 = $dbh->prepare('select max(IMPORTDATE) from Cell');
		$sth3->execute;
		my ($maxdate) = $sth3->fetchrow_array;
		if (array_exists(\@tables,$tname)) {
			my $regLen = length($region);
			$sth = $dbh->prepare("select BSCNAME, SITE, LAC, CI, CELL_NAME, LAT, LON, ASIMUTH, DOWNTILT, ERP, HEIGHT FROM $tname WHERE LAT <> '' AND LON <> '' AND CI <> '' AND SUBSTRING(BSCNAME,1,$regLen) = '$region';");
			if ($sth) {
				$sth->execute;
				while ( my @row = $sth->fetchrow_array ) {
					next unless defined $row[1];
					# motorola sites:
					$row[4] =~ s/^\d{2}\-//;
					$sites{$row[0].'/'.$row[1]}{$row[2].'/'.$row[3]} = [ (@row[2..10]) ];
					#print "@row\n";
				}
			}
			else {
				$dbh->disconnect;
				die $dbh->errstr;
			}
		}
		else {
			$dbh->disconnect;
			die "Table $tname does not exist!";
		}

		print OUTFILE <<TILLR;
  <Folder>
   <name>$Regions{$region}</name>
TILLR
	
		# get site info for each site
		for my $site (sort {$sites{$a}->{(keys %{$sites{$a}})[0]}[2] cmp $sites{$b}->{(keys %{$sites{$b}})[0]}[2]} keys %sites) {
			my $size = 48;
			my $sname = "";
			my %cis = ();
			my ($lat,$lon);
			my @azimuths = ();
			my $maxsectors = 3;
			for my $sector (sort keys %{$sites{$site}}) {
				last if (!$maxsectors--);
				push @azimuths, $sites{$site}->{$sector}[5];
				$sname = $sites{$site}->{$sector}[2];
				$cis{$sites{$site}->{$sector}[1]} = $sites{$site}->{$sector}[5];
				$lat = $sites{$site}->{$sector}[3];
				$lon = $sites{$site}->{$sector}[4];
				if (TRANSFORM) {
				my ($to_lat, $to_lon, undef) = molodensky (($lat / $degrees_per_radian), ($lon/$degrees_per_radian), 0,
	            $equatorial, $flattening, $eccentricity_squared,
	            ($to_equatorial - $equatorial), ($to_flattening - $flattening), @{$DatumDeltaWGS84{'CAPE'}} );
				$lat = $to_lat * $degrees_per_radian;
				$lon = $to_lon * $degrees_per_radian;
				}
				$lat = sprintf("%.8f",$lat);	# remove micron precision - actually 6 places is enough
				$lon = sprintf("%.8f",$lon);
			}
			my $omni = 1;
			
			if ($sname =~ s/[_,\-](\d)$//) {
				if ($1) {
					$omni=0;
				}
			}
			my $pic = "omni";
			if ($sname =~ /_MC\d$/i) {
				$omni=1;
				#$size = 16;
				$pic = "micro";
			}
			print "$sname ",join(",",sort({$a <=> $b} @azimuths)),$omni?" Omni":"","\n" if (VERBOSE);
			if (!$omni) {
				$pic = best_fit(scalar(@azimuths),@azimuths);
			}
			print OUTFILE <<TILLHERED1;
   <Placemark>
	<name>$sname</name>
	<description>
<![CDATA[
TILLHERED1
			for my $ci (sort keys %cis) {
				print OUTFILE "CI:$ci @ $cis{$ci} \n";
			}
			print OUTFILE <<TILLHERED2;
]]>
	</description>
	<styleUrl>#$pic$region</styleUrl>
	<Point>
	 <coordinates>$lon,$lat,0</coordinates>
	</Point>
   </Placemark>
TILLHERED2
		}
		# end of a region
		print OUTFILE <<TILLER;
  </Folder>
TILLER
		
	}

	if (MAKE_MYPLACES) {
		print OUTFILE <<TILLMPL2;
  </Document>
 </Folder>
TILLMPL2
	}
	print OUTFILE <<TILLHERE2;
 </Document>
</kml>
TILLHERE2
	
	close OUTFILE;
}

sub best_fit {
	my ($numsectors, @azimuths) = @_;
	my $pic = "omni";
	if ($numsectors) {
		#my %allocations = map {$_ => 0}, @Azimuths;
		my %allocations = ();
		for my $a (@Azimuths) {
			my $mina = $a-($Width/2);
			print "checking for $mina ... " if (VERBOSE);
			for my $i (0..$numsectors-1) {
				if (angleIsInPie($azimuths[$i],$mina, $Width)) {
					print " match for $azimuths[$i] => $a " if (VERBOSE);
					$allocations{$a}++;
					if ($allocations{$a} > 1) {
						print "Repeated sector!\n" if (VERBOSE);
					}
				}
			}	
		}
		if (scalar keys %allocations) {
			$pic = join ('_', (sort {$a <=> $b} keys %allocations));
			print "Pic will be: $pic \n" if (VERBOSE);
		}
	}
	return $pic;
}

sub angleIsInPie {
	my ($angle, $from, $piewidth) = @_;
	my $offset = $from % 360;

	$angle = ($angle - $offset) % 360;
	
	if ($angle < $piewidth) {
		return 1;
	}
	return 0;	
}

sub array_exists {
	my ($aryref, $keyword) = @_;
	for (@{$aryref}) {
		return (1) if (lc($_) eq lc($keyword));
	}
	return (0);
}

## connect to db
sub connect_db {
  my $dsn = 'DBI:mysql:alcatelRSA;host=127.0.0.1;port=3306';
  my $dbh_c = DBI->connect($dsn, 'tools', 'alcatel');
  return $dbh_c;
}

sub molodensky {
#    Molodensky Datum Transformation
#    Parameters:
#		from:     The geodetic position to be translated. (lat in radians, lon in radians, height in meters above ellipsoid)
#		from_a:   The semi-major axis of the "from" ellipsoid.
#		from_f:   Flattening of the "from" ellipsoid.
#		from_esq: Eccentricity-squared of the "from" ellipsoid.
#		da:       Change in semi-major axis length (meters); "to" minus "from"    
#		df:       Change in flattening; "to" minus "from"
#		dx:       Change in x between "from" and "to" datum.
#		dy:       Change in y between "from" and "to" datum.
#		dz:       Change in z between "from" and "to" datum.
    my (	$from_lat, $from_lon, $from_h,
            $from_a, $from_f, $from_esq,
            $da, $df, $dx, $dy, $dz
       ) = @_;

        my $slat = sin ($from_lat);
        my $clat = cos ($from_lat);
        my $slon = sin ($from_lon);
        my $clon = cos ($from_lon);
        my $ssqlat = $slat * $slat;
        my $adb = 1.0 / (1.0 - $from_f);  # "a divided by b"

        my $rn = $from_a / sqrt(1.0 - $from_esq * $ssqlat);
        my $rm = $from_a * (1.0 - $from_esq) / ((1.0 - $from_esq * $ssqlat)**1.5);

        my $dlat = (((((-$dx * $slat * $clon - $dy * $slat * $slon) + $dz * $clat)
                    + ($da * (($rn * $from_esq * $slat * $clat) / $from_a)))
                + ($df * ($rm * $adb + $rn / $adb) * $slat * $clat)))
            / ($rm + $from_h);

        my $dlon = (-$dx * $slon + $dy * $clon) / (($rn + $from_h) * $clat);

        my $dh = ($dx * $clat * $clon) + ($dy * $clat * $slon) + ($dz * $slat)
             - ($da * ($from_a / $rn)) + (($df * $rn * $ssqlat) / $adb);

        return ($from_lat + $dlat, $from_lon + $dlon, $from_h + $dh);
}

__END__
