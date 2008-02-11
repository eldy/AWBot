#!/usr/bin/perl
#-------------------------------------------------------
# Name: formatsnif.pl
# Description: Analyze a snif file and build a text file with HTTP request only
# to build easily an AWBot config file.
# Snif files supported: Sniffer Pro .cap files
# Required modules: None
#-------------------------------------------------------
# $Revision$ - $Author$ - $Date$
use strict; no strict "refs";
$|=1;		# Force flush of disk writing


#-------------------------------------------------------
# Defines
#-------------------------------------------------------
use vars qw/ $REVISION $VERSION /;
my $REVISION='$Revision$'; $REVISION =~ /\s(.*)\s/; $REVISION=$1;
my $VERSION="1.0 (build $REVISION)";

my $DEBUGFORCED=0;				# Force debug level to log lesser level into debug.log file (Keep this value to 0)
my $nowtime = my $nowweekofmonth = my $nowdaymod = my $nowsmallyear = 0;
my $nowsec = my $nowmin = my $nowhour = my $nowday = my $nowmonth = my $nowyear = my $nowwday = 0;

use vars qw/
$DIR $PROG $Extension
$QueryString
$SnifFile
$Debug $DebugResetDone
$starttime $endtime
/;
$SnifFile="";
$Debug=0;



#-----------------------------------------------------------------------------
# Functions
#-----------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Function:   Return a string with current date/time 
# Parameters: -
# Return:     Current date time with format YYYY/MM/DD-HH:MM:SS:ms
# Input var:  -
# Output var: -
#------------------------------------------------------------------------------
sub showtime() {
	my ($nowsec,$nowmin,$nowhour,$nowday,$nowmonth,$nowyear,$nowwday,$nowyday,$nowisdst) = localtime();
	$nowyear+=1900;++$nowmonth;
	return sprintf("%04d/%02d/%02d-%02d:%02d:%02d",$nowyear,$nowmonth,$nowday,$nowhour,$nowmin,$nowsec);
}

#-----------------------------------------------------------------------------
# Function:     Print an error string an stop program
# Parameters:	string_message
# Return:		PROGRAM STOPPED
# Input var:	-
# Output var:	-
#-----------------------------------------------------------------------------
sub error {
	my $message=shift||"";
	if ($message) { print "$message\n"; }
	exit 1;
}

#-----------------------------------------------------------------------------
# Function:     Print an debug message if debug_level is debug asked
# Parameters:	string_message [debug_level]
# Return:		-
# Input var:	$DEBUGFORCED
# Output var:	-
#-----------------------------------------------------------------------------
sub debug {
	my $level = $_[1] || 1;
	if ($level <= $DEBUGFORCED) {
		my $debugstring = $_[0];
		if (! $DebugResetDone) { open(DEBUGFORCEDFILE,"$PROG.log"); close DEBUGFORCEDFILE; chmod 0666,"$PROG.log"; $DebugResetDone=1; }
		open(DEBUGFORCEDFILE,">>$PROG.log");
		print DEBUGFORCEDFILE localtime(time)." - $$ - DEBUG $level - $debugstring\n";
		close DEBUGFORCEDFILE;
	}
	if ($level <= $Debug) {
		my $debugstring = $_[0];
		print showtime()." - DEBUG $level - $debugstring\n";
	}
}

#--------------------------------------------------------------------
# Function:     Decode an URL encoded string
# Parameters:	stringtodecode
# Return:		decodedstring
# Input var:	-
# Output var:	-
#--------------------------------------------------------------------
sub DecodeEncodedString {
	my $stringtodecode=shift;
	$stringtodecode =~ tr/\+/ /s;
	$stringtodecode =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;		# Decode encoded URL
	return $stringtodecode;
}

#--------------------------------------------------------------------
# Function:     Split different part of frame: dlc, ip, tcp
# Parameters:	stringtodecode
# Return:	 	(dlc,ip,tcp)
# Input var:	-
# Output var:	-
#--------------------------------------------------------------------
sub SplitFrame {
	my $stringtodecode=shift;
	my $dlc=substr($stringtodecode,0,14);
	my $ip=substr($stringtodecode,14,34);
	my $tcp=substr($stringtodecode,34);
	return ($dlc,$ip,$tcp);
}



#-------------------------------------------------------
# MAIN
#-------------------------------------------------------
$nowtime=time();
# Get current time
($nowsec,$nowmin,$nowhour,$nowday,$nowmonth,$nowyear,$nowwday) = localtime($nowtime);
if ($nowyear < 100) { $nowyear+=2000; } else { $nowyear+=1900; }
$nowsmallyear=$nowyear;$nowsmallyear =~ s/^..//;
if (++$nowmonth < 10) { $nowmonth = "0$nowmonth"; }
if ($nowday < 10) { $nowday = "0$nowday"; }
if ($nowhour < 10) { $nowhour = "0$nowhour"; }
if ($nowmin < 10) { $nowmin = "0$nowmin"; }
if ($nowsec < 10) { $nowsec = "0$nowsec"; }

($DIR=$0) =~ s/([^\/\\]*)$//; ($PROG=$1) =~ s/\.([^\.]*)$//; $Extension=$1;
$DIR =~ s/([\\\/]*)bin([\\\/]*)$//i;

# Define QueryString (string with all parameters)
$QueryString=""; for (0..@ARGV-1) {
	#if ($_ > 0) { $QueryString .= "&"; }
	$QueryString .= "&";
	my $NewLinkParams=$ARGV[$_]; $NewLinkParams =~ s/^-+//; $NewLinkParams =~ s/\s/%20/g;
	$QueryString .= "$NewLinkParams";
}

if ($QueryString =~ /&file=([^& ]+)/i)	    { $SnifFile=$1; }
if ($QueryString =~ /&debug=(\d+)/i)	{ $Debug=$1; }

# Recuperation parametres entree
if ($ARGV[0] eq "-h" || ! $SnifFile) {
	print "----- $PROG $VERSION -----\n";
	print "$PROG allows you to format a snif file to build a text file\n";
	print "that contains clear HTTP URL requests and parameters.\n";
	print "Supported snif files are:\n";
	print "Sniffer PRO .cap files\n";
	print "Usage: $PROG.$Extension -file=testconfigfile [options]\n";
	print "\n";
	print "Where options are:\n";
	print "  -debug=d       d is debug level\n";
	sleep 3;
	exit 1;
}
print "----- $PROG $VERSION -----\n";

# Open snif file
open(SNIFFILE,"<$SnifFile") || error("Error: Failed to open snif file $SnifFile.");
binmode SNIFFILE;
my $prot='';
while (<SNIFFILE>) {

	# Analyze line
	my ($dlc,$ip,$tcp)=();

	if ($_ =~ /(.{14})(.{20})(GET .* HTTP\/.*)/msi) { ($dlc,$ip,$tcp)=($1,$2,$3); }
	elsif ($_ =~ /(.{14})(.{20})(POST .* HTTP\/.*)/msi) { ($dlc,$ip,$tcp)=($1,$2,$3); }

	#debug("_=$_");
	debug("dlc=$dlc");
	debug("ip=$ip");
	debug("tcp=$tcp");

	# If line contains an HTTP GET request
	if ($tcp =~ /get (.*) http\//i) {
		$prot='GET';
		my $url="$1";
		my ($urlwithnoparam,$param)=split(/\?/,$url,2);
		if ($urlwithnoparam !~ /\.gif$/i && $urlwithnoparam !~ /\.png$/i ) {
			debug("Found an HTTP request. Qualified (not image file).");
			print "GET $url\n";
		}
		else {
			debug("Found an HTTP request. Skipped (image file).");
		}
		next;
	}

	# If line contains an HTTP POST request
	if ($tcp =~ /post (.*) http\//i) {
		$prot='POST';
		my $url="$1";
		my ($urlwithnoparam,$param)=split(/\?/,$url,2);
		if ($urlwithnoparam !~ /\.gif$/i && $urlwithnoparam !~ /\.png$/i ) {
			debug("Found an HTTP request. Qualified (not image file).");
			print "POST $url\n";
		}
		else {
			debug("Found an HTTP request. Skipped (image file).");
		}
		next;
	}


}
close(SNIFFILE);

$endtime=time();

0;
