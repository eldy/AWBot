#!/usr/bin/perl
#-------------------------------------------------------
# Name: awbotlaunch.pl
# Description: Launch n session of awbot
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
$QueryString $ConfigFile
$Delay $NbSessions $StartSession $NoWait $Debug $PrepareOnce $Server
$command $retour $starttime $endtime $bidon
$IDLauncher $NoStopIfError
$AuthenticationFile
@userarray @passwordarray
/;
$Server="";
$ConfigFile="";
$AuthenticationFile="";
$Debug=0;
$StartSession=1;
$PrepareOnce=0;



#-----------------------------------------------------------------------------
# Functions
#-----------------------------------------------------------------------------

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

#-----------------------------------------------------------------------------
# Function:     Read an authentication file with format "user	password"
#               and load userarray and passwordarray.
# Parameters:	filename
# Return:		0 Ok, 1 Error
# Input var:	-
# Output var:	$userarray $passwordarray
#-----------------------------------------------------------------------------
sub Read_Authentication_File
{
	my $filename=shift;

	# Open file
	my $openok=0;

	if (open(AUTHFILE,"$filename")) { $openok=1; }
	if (! $openok) { &error("Error: Couldn't open authentication file \"$filename\" : $!"); }

	# Loop on file lines
	my $linenumber=0;
	while(<AUTHFILE>)
	{
		chomp $_; s/\r//;
		if ($_ =~ /^#/) { next; }
		my @field=split(/\s+/,$_);
		if ($field[0]) {
			$linenumber++;
			$userarray[$linenumber]=$field[0];
			$passwordarray[$linenumber]=$field[1];
#			print "Load userarray/passwordarray for entry $linenumber with value $userarray[$linenumber]/$passwordarray[$linenumber]\n";
		}
	}
	
	close AUTHFILE;
}




#-------------------------------------------------------
# MAIN
#-------------------------------------------------------
$nowtime=time;
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

if ($QueryString =~ /&config=([^\s&]+)/i)			{ $ConfigFile=&DecodeEncodedString($1); }
if ($QueryString =~ /&authentication=([^\s&]+)/i)	{ $AuthenticationFile=&DecodeEncodedString($1); }
if ($QueryString =~ /&startsession=(\d+)/i)	{ $StartSession=$1; }
if ($QueryString =~ /&nbsessions=(\d+)/i)	{ $NbSessions=$1; }
if ($QueryString =~ /&delay=([^ &]*)/i)		{ $Delay=$1; }
if ($QueryString =~ /&prepareonce/i)		{ $PrepareOnce=1; }
if ($QueryString =~ /&server=([^ &]*)/i)	{ $Server=$1; }
if ($QueryString =~ /&debug=(\d+)/i)		{ $Debug=$1; }
if ($QueryString =~ /&nostopiferror/i)	    { $NoStopIfError=1; }

my $botname=$PROG; $botname =~ s/launch$//g;

# Recuperation parametres entree
if ($ARGV[0] eq "-h" || $NbSessions < 1 || ! $ConfigFile) {
	print "----- $PROG $VERSION -----\n";
	print "$PROG allows you to launch several simultaneous sessions of $botname.\n";
	print "All output files of all sessions are stored in '$PROG' directory.\n";
	print "Usage: $PROG.$Extension -config=testconfigfile -nbsessions=n [options]\n";
	print "\n";
	print "Where options are:\n";
	print "  -startsession=n where n is number used as first number for sessions counter.\n";
	print "  -delay=d        where d is delay between each URL to test:\n";
	print "                   -1 wait a key\n";
	print "                   0 no delay\n";
	print "                   n wait n seconds\n";
	print " -prepareonce     a botname session will be ran with -prepareonly, then\n";
	print "                  all sessions will be ran with -executeonly (so prepare\n";
	print "                  statements will be execute only once for all sessions.\n";
	print "  -nostopiferror  $botname will continue with next test when an error occurs.\n";
	print "  -authentication=user/password|\@userpasswordfile\n";
	print "                  with user/password, config file values for USER and PASSWORD\n";
	print "                  are overwritten.\n";
	print "                  with \@userpasswordfile, users and passwords in file will be\n";
	print "                  used. If nbsessions is higher than number of file records,\n";
	print "                  users at the beginning of file are geet a next time.\n";
	sleep 3;
	exit 1;
}
print "----- $PROG $VERSION ($NbSessions sessions) -----\n";

# Read authentication file to init usersarray and passwordsarray
@userarray=@passwordarray=();
if ($AuthenticationFile) {
	if ($AuthenticationFile =~ /^\@.+/) {
		# $AuthenticationFile=@FileName
		my $filename=$AuthenticationFile;
		$filename =~ s/^\@//;
		&Read_Authentication_File($filename);
	}
	else {
		if ($AuthenticationFile =~ /(.+)\/(.+)/) {
			# $AuthenticationFile=user/password
			$userarray[1]=$1;
			$passwordarray[1]=$2;
		}
		else {
			$userarray[1]=$AuthenticationFile;
		}
	}
}

# Launch prepare phase
if ($PrepareOnce) {
	my $dirnamebot="$DIR";
	if ($dirnamebot && $dirnamebot =~ /[\\\/]$/) { $dirnamebot.="/"; }
	$dirnamebot.="$botname.pl";
	$command="$dirnamebot -config=\"$ConfigFile\" -startsession=".($StartSession)." -nbsessions=$NbSessions -prepareonly -silent";
	if ($Delay)  { $command.=" -delay=$Delay"; }
	if ($Server) { $command.=" -server=$Server"; }
	if ($NoStopIfError) { $command.=" -nostopiferror"; }
	if ($Debug)  { $command.=" -debug=$Debug"; }
	print "Launch PRE ACTIONS phase : $command\n";
	$retour=`perl $command 2>&1`;
	if ($retour =~ /failed/i) {
		&error("Failed to prepare test: $retour");
	}
}
$starttime=time();

$IDLauncher=$$;

# Launch action phase for all sessions (6Mb required by son).
my $usercpt=0;
foreach my $num (1..$NbSessions) {
	# Increase child process counter
	$usercpt++;
	if ($usercpt >= @userarray) { $usercpt=1; }
	# Launch child process
    my $pid = fork;
    defined $pid or &error("fork ($!)");
    if (! $pid) {
		# child code
		my $dirnamebot="$DIR";
		if ($dirnamebot && $dirnamebot =~ /[\\\/]$/) { $dirnamebot.="/"; }
		$dirnamebot.="$botname.pl";
		$command="$dirnamebot -config=\"$ConfigFile\" -startsession=".($StartSession)." -numsession=".($num+$StartSession-1)." -nbsessions=$NbSessions -silent -id=$IDLauncher";
		if ($PrepareOnce) { $command.=" -executeonly"; }
		if ($Delay)  { $command.=" -delay=$Delay"; }
		if ($Server) { $command.=" -server=$Server"; }
		if ($NoStopIfError) { $command.=" -nostopiferror"; }
		if ($userarray[$usercpt]) {
			$command.=" -user=$userarray[$usercpt]";
			if ($passwordarray[$usercpt]) {
				$command.=" -password=$passwordarray[$usercpt]";
			}		
		}
		if ($Debug)  { $command.=" -debug=$Debug"; }
		print "Launch $botname process $num : $command\n";
		my $ret=exec($command);
		# We never reach this part of code
		# exec() has replaced process
	}
}

# Wait end of each child process
foreach my $num (1..$NbSessions) {
	wait();
}
sleep(1);

$endtime=time();

print "End of running $NbSessions sessions. Absolute duration: ".($endtime-$starttime)."s\n";

0;
