#!/usr/bin/perl
#-----------------------------------------------------------------------------
# Name: awbot.pl
# Description: Web visitor robot for web application testing or benchmark analysis
# Required modules:
# Time::HiRes, LWP::UserAgent, HTTP::Cookies, HTTP::Headers, HTTP::Request
# DBI, DBD:xxx where xxx is your database engine (if you use one)
#-----------------------------------------------------------------------------
# $Revision$ - $Author$ - $Date$

#use strict; no strict "refs";
$|=1;		# Force flush of disk writing

use Time::HiRes qw( gettimeofday tv_interval );
use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Headers;
use HTTP::Request;

# If you use database direct access (using SEQUENCE or SQL directives in test
# file), you must choose here your database perl driver
#__START_OF_SGBD_SETUP
#use DBD::Oracle;
#use DBD::Sybase;
#use DBD::ODBC;
#use DBD::mysql;
#__END_OF_SGBD_SETUP


#-----------------------------------------------------------------------------
# Defines
#-----------------------------------------------------------------------------
use vars qw/ $REVISION $VERSION /;
$REVISION='$Revision$'; $REVISION =~ /\s(.*)\s/; $REVISION=$1;
$VERSION="1.1 (build $REVISION)";

my $DEBUGFORCED=0;				# Force debug level to log lesser level into debug.log file (Keep this value to 0)
my $nowtime = my $nowweekofmonth = my $nowdaymod = my $nowsmallyear = 0;
my $nowsec = my $nowmin = my $nowhour = my $nowday = my $nowmonth = my $nowyear = my $nowwday = 0;

use vars qw/
$Location
$starttime
$ConfigFile $OutputFile
$DIR $PROG $Extension $BotName
$DEBUG $DELAY $TIMEOUT $PrepareOnly $ExecuteOnly $Wait $MaxSize $STARTSESSION $NUMSESSION $NBSESSIONS
$QueryString
%AllowedActions
$BASEENGINE $DSN $USERBASE $PASSWORDBASE
$SERVER $USER $PASSWORD $PROXYSERVER @HOSTSNOPROXY
@PREACTIONS @POSTACTIONS
@ActionsTypeInit @ActionsValueInit
$NbOfUrlInit $NbOfAutoInit
%LISTESEQUENCEURSAVED
$NbOfRequestsSent $NbOfRequestsReturnedSuccessfull
$lasturlinerror
$Debug $DebugResetDone
$Verbose $Silent
$ID $NoStopIfError
$LoadImages $Output
$dbh
$PARAM
$HTTPcookie
$HTTPheader
$HTTPua
$HTTPResponseWithHeader $HTTPResponse
$delay $savseconds $savmicroseconds
%CheckYesTotal %CheckNoTotal %CheckYesOk %CheckNoOk
%ActionsDuration $ActionsMinDuration $ActionsMaxDuration
%ActionsUp $ActionsMinUp $ActionsMaxUp
%ActionsDown $ActionsMinDown $ActionsMaxDown
$HTMLOutput
%Message
$Lang
$DirLang $DirConfig
/;
$Lang="en";
$HTMLOutput=0;
$DebugResetDone=0;
$ID=0;
$NoStopIfError=0;
$Wait=0;
$Output=1;
$MaxSize=0;
$Debug=0;
$NbOfUrlInit=0;
$AutoExists=0;
$Verbose=0; $Silent=0;
$STARTSESSION=1;
$NUMSESSION=1;
$NBSESSIONS=1;
$DirLang=$DirConfig="";
%AllowedActions=(AUTO=>1,GET=>1,POST=>1,CHECKYES=>1,CHECKNO=>1,VAR=>1,SEQUENCE=>1,SQL=>1,SCRIPT=>1,WRITETO=>1,WRITETOH=>1);

@HOSTSNOPROXY = ("myhost1","myhost1.my.domain.name");



#-----------------------------------------------------------------------------
# Fonctions
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
	# Restauration etat initial de la base
	if (! $ExecuteOnly) {
		if (scalar keys %LISTESEQUENCEURSAVED) {
			# Restore sequence
			foreach my $sequence (keys %LISTESEQUENCEURSAVED) {
				if ($LISTESEQUENCEURSAVED{$sequence}) {
					# Restore sequence value if saved with a value not ""
					restore_sequence($sequence);
				}
			}
		}
	}
	CloseConnect();
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
		if ($HTMLOutput) { $debugstring =~ s/^ /&nbsp&nbsp /; $debugstring .= "<br>"; }
		print showtime()." - DEBUG $level - $debugstring\n";
	}
}


#-----------------------------------------------------------------------------
# Function:     Read language data
# Parameters:	Language_code  ("fr","en"...)
# Return:		-
# Input var:	$DIR $DirLang
# Output var:	%Mesage hash array
#-----------------------------------------------------------------------------
sub Eval {
	my $stringtoeval=shift||"";

	return $res;
}	
	
#-----------------------------------------------------------------------------
# Function:     Read language data
# Parameters:	Language_code  ("fr","en"...)
# Return:		-
# Input var:	$DIR $DirLang
# Output var:	%Mesage hash array
#-----------------------------------------------------------------------------
sub Read_Language_Data {
	my $FileLang="";
	foreach my $dir ("$DirLang","$DIR/lang","./lang") {
		my $searchdir=$dir;
		if ($searchdir && (!($searchdir =~ /\/$/)) && (!($searchdir =~ /\\$/)) ) { $searchdir .= "/"; }
		if (! $FileLang) { if (open(LANG,"${searchdir}awbot-$_[0].txt")) { $FileLang="${searchdir}awbot-$_[0].txt"; } }
	}
	# If file not found, we try english
	foreach my $dir ("$DirLang","${DIR}lang","./lang") {
		my $searchdir=$dir;
		if ($searchdir && (!($searchdir =~ /\/$/)) && (!($searchdir =~ /\\$/)) ) { $searchdir .= "/"; }
		if (! $FileLang) { if (open(LANG,"${searchdir}awbot-en.txt")) { $FileLang="${searchdir}awbot-en.txt"; } }
	}
	if ($Debug) { debug("Call to Read_Language_Data [FileLang=\"$FileLang\"]"); }
	if ($FileLang) {
		while (<LANG>) {
			chomp $_; s/\r//;
			if ($_ =~ /^PageCode/i) {
				$_ =~ s/^PageCode=//i;
				$_ =~ s/#.*//;								# Remove comments
				$_ =~ tr/\t /  /s;							# Change all blanks into " "
				$_ =~ s/^\s+//; $_ =~ s/\s+$//;
				$_ =~ s/^\"//; $_ =~ s/\"$//;
				$PageCode = $_;
			}
			else {
				$_ =~ s/#.*//;								# Remove comments
				$_ =~ tr/\t /  /s;							# Change all blanks into " "
				$_ =~ s/^\s+//; $_ =~ s/\s+$//;
				my @fields=split(/=/,$_,2);
				#print "A $fields[0] $fields[1] A\n";
				debug("Load message file $fields[0] with $fields[1]",4);
				$Message{$fields[0]} = eval($fields[1]);
			}
		}
	}
	else {
		&warning("Warning: Can't find language files for \"$_[0]\". English will be used.");
	}
	close(LANG);
}


#-----------------------------------------------------------------------------
# Function:     Find and read config file
# Parameters:	-
# Return:		-
# Input var:	$ConfigFile
# Output var:	All variables defined and read in config file
#-----------------------------------------------------------------------------
sub Read_Config_File
{
	my $PREACTIONSPHASE=0;
	my $ACTIONSPHASE=0;
	my $POSTACTIONSPHASE=0;

	# Open file
	my $openok=0;
	foreach my $dir ("","$DIR","$DIR/conf","./conf","/etc/opt/awbot","/etc/awbot","/etc","/usr/local/etc/awbot") {
		my $searchdir=$dir;
		if (($searchdir ne "") && (!($searchdir =~ /\/$/)) && (!($searchdir =~ /\\$/)) ) { $searchdir .= "/"; }
		if (open(CONFIG,"$searchdir$ConfigFile"))  { $DirConfig=$searchdir; $openok=1; last; }
	}
	if (! $openok) { error("Error: Couldn't open config file \"$ConfigFile\" : $!"); }

	if ($Debug) { debug("Call to Read_Config_File [ConfigFile=\"$DirConfig$ConfigFile\"]"); }

	# parcours du fichier
	my $linenumber=0;
	while(<CONFIG>)
	{
		chomp $_; s/\r//;
		$linenumber++;
		if ($_ =~ /^$/) { next; }
		# Remove comments
		if ($_ =~ /^#/) { next; }
		my $line = $_;
		$line =~ s/^([^\"]*)#.*/$1/;
		$line =~ s/^([^\"]*\"[^\"]*\"[^\"]*)#.*/$1/;
		if ($Debug) { debug("$_",4); }
		$line =~ s/^\s+//; $line =~ s/\s+$//;
		# Replace __MONENV__ with value of environnement variable MONENV
		$line =~ s/__(\w+)__/$ENV{$1}/g;
		if (! $PREACTIONSPHASE && ! $ACTIONSPHASE && ! $POSTACTIONSPHASE) {
			# Read main section
			if ($line =~ /^OUTPUTDIR\s*=\s*(.*)/)   { $OutputDir=eval($1); next; }
			if ($line =~ /^BOTNAME\s*=\s*(.*)/)     { $BotName=eval($1); next; }
			if ($line =~ /^DELAY\s*=\s*(\d+)/)      { $DELAY=$1; next; }
			if ($line =~ /^TIMEOUT\s*=\s*(\d+)/)    { $TIMEOUT=$1; next; }
			if ($line =~ /^OUTPUT\s*=\s*(\d+)/)     { $Output = $1; next; }
			if ($line =~ /^BASEENGINE\s*=\s*(.*)/)   { $BASEENGINE=eval($1); next; }
			if ($line =~ /^DSN\s*=\s*(.*)/)          { $DSN=eval($1); next; }
			if ($line =~ /^USERBASE\s*=\s*(.*)/)     { $USERBASE = eval($1); next; }
			if ($line =~ /^PASSWORDBASE\s*=\s*(.*)/) { $PASSWORDBASE=eval($1); next; }
			if ($line =~ /^SERVER\s*=\s*(.*)/)		{ $SERVER=eval($1); next; }
			if ($line =~ /^USER\s*=\s*(.*)/)		{ $USER=eval($1); next; }
			if ($line =~ /^PASSWORD\s*=\s*(.*)/)	{ $PASSWORD=eval($1); next; }
			if ($line =~ /^PROXYSERVER\s*=\s*(.*)/)	{ $PROXYSERVER=eval($1); next; }
			if ($line =~ /^LANG\s*=\s*(.*)/)		{ $Lang=eval($1); next; }
			if ($line =~ /^(PARAM\d*)\s*=\s*(.*)/)	{ my $var = "$1"; $$var = eval($2); next; }
		}

		if ($line =~/<PRE ACTIONS/)    { $PREACTIONSPHASE = 1; next; }
		if ($line =~/<\/PRE ACTIONS/)  { $PREACTIONSPHASE = 0; next;  }
		if ($line =~/<ACTIONS/)        { $ACTIONSPHASE = 1; next;  }
		if ($line =~/<\/ACTIONS/)      { $ACTIONSPHASE = 0; next;  }
		if ($line =~/<POST ACTIONS/)   { $POSTACTIONSPHASE = 1; next;  }
		if ($line =~/<\/POST ACTIONS/) { $POSTACTIONSPHASE = 0; next;  }

		if ($PREACTIONSPHASE)
		{
			&debug(" Find PREACTIONS: $line",3);
			push @PREACTIONS, "$line";
		}
		if ($ACTIONSPHASE)
		{
			# 	
			my @array=split(/[\s,]+/,"$line");
			my $arraycursor=0;
			while ($array[$arraycursor]) {
				#my $actionnb=sprintf("%05d",$ACTIONSPHASE);
				my $actionnb=int($ACTIONSPHASE);
				$ActionsTypeInit[$actionnb]=$array[$arraycursor++];
				if (! $AllowedActions{$ActionsTypeInit[$actionnb]}) {
					error("Syntax error in config file $ConfigFile line $linenumber : Unknown Action '$ActionsTypeInit[$actionnb]' in ACTIONS section.");
					exit 1;
				}
				$ActionsValueInit[$actionnb]=$array[$arraycursor];
				if ($array[$arraycursor] =~ /^[\"\'].*[^\"\']$/) {
					do {
						$arraycursor++;
						$ActionsValueInit[$actionnb].=" ".$array[$arraycursor];
					}
					while ($array[$arraycursor] !~ /[\"\']$/ && $array[$arraycursor+1])
				}
				$arraycursor++;
				#if ($ActionsValueInit[$actionnb] =~ /^\"(.*)\"$/) { $ActionsValueInit[$actionnb]=$1; }
				if ($ActionsTypeInit[$actionnb] =~ /get/i || $ActionsTypeInit[$actionnb] =~ /post/i) {
					$NbOfUrlInit++;
				}
				if ($ActionsTypeInit[$actionnb] =~ /auto/i) {
					$NbOfAutoInit++;
				}
				&debug(" Find action $ACTIONSPHASE: \"$ActionsTypeInit[$actionnb]\" - $ActionsValueInit[$actionnb]",3);
				$ACTIONSPHASE++;
			}
		}
		if ($POSTACTIONSPHASE)
		{
			&debug(" Find POSTACTIONS: $line",3);
			push @POSTACTIONS, "$line";
		}
	}
	
	close CONFIG;
	if (! $OutputDir) {
		&error("Error: OUTPUTDIR is not defined if '$DirConfig$ConfigFile'.\n");
		exit 1;
	}
}


#-----------------------------------------------------------------------------
# Function:     Evaluate calue Init value of PARAMx
# Parameters:	-
# Return:		-
# Input var:	$PARAMx	
# Output var:	$PARAMx
#-----------------------------------------------------------------------------
sub init_var
{
	foreach my $i (1..99)
	{
		my $var = "PARAM$i";
		if ($$var && ($$var =~ /^SELECT/i))
		{
			OpenConnect();	# Open database connexion if not opened
			my $requete = $$var;
			my $sth = $dbh->prepare($requete) || error("Error: Init of param PARAM$i failed. Failed to prepare $requete:".$dbh->err.", ".$dbh->errstr);
			$sth->execute || error("Error: Init of param PARAM$i failed. Failed to execute $requete:".$dbh->err.", ".$dbh->errstr);
			$$var = $sth->fetchrow_array;
			$sth->finish;
		}
#		else {
#			$$var=eval($$var);
#		}
	}
}


#-----------------------------------------------------------------------------
# Function:     Set a sequence to a particular value (and save old value)
# Parameters:	sequence_name
# Return:		0 OK, 1 Already set, 2 Error
# Input var:	$dbh=database handler
# Output var:	$LISTESEQUENCEURSAVED{$sequence}=old value saved
#-----------------------------------------------------------------------------
sub set_sequence {
	my $sequence=shift;
	my $value=shift;
	if ($LISTESEQUENCEURSAVED{$sequence}) {
		error("Sequence $sequence was already changed");
		return 1;
	}
	debug("set_sequence($sequence,$value)",2);

	# TODO Save old value
	$LISTESEQUENCEURSAVED{$sequence}="";

	# Change sequence
	debug(" Drop sequence $sequence",3);
	my $sth = $dbh->prepare("drop sequence $sequence") || die "Unable to prepare query:".$dbh->err.", ".$dbh->errstr;
	$sth->execute;
	$sth->finish;
	debug(" Create sequence $sequence with value $value",3);
	$sth = $dbh->prepare("create sequence $sequence start with $value") || die "Unable to prepare query:".$dbh->err.", ".$dbh->errstr;
	$sth->execute || die "Unable to execute query:".$dbh->err.", ".$dbh->errstr;
	$sth->finish;
	return 0;
}

#-----------------------------------------------------------------------------
# Function:     Set back a sequence to its original value
# Parameters:	sequence_name
# Return:		1 OK, 0 Error
# Input var:	$dbh=database handler
# Output var:	-	
#-----------------------------------------------------------------------------
sub restore_sequence {
	my $sequence = shift;
	debug("restore_sequence ($sequence)",2);
	debug(" Drop sequence $sequence",3);
	my $sth = $dbh->prepare("drop sequence $sequence") || die "Unable to prepare query:".$dbh->err.", ".$dbh->errstr;
	$sth->execute || die "Unable to execute query:".$dbh->err.", ".$dbh->errstr;
	$sth->finish;
#		debug("Recupere valeur max de ID_$sequence",2);
#		$sth = $dbh->prepare("select max(ID_$sequence) from $sequence where ID_$sequence<9999") || die "Unable to prepare query:".$dbh->err.", ".$dbh->errstr;
#		$sth->execute || die "Unable to execute query:".$dbh->err.", ".$dbh->errstr;
#		while (my $row = $sth->fetchrow_arrayref) {
#			($numseq) = @$row;
#			debug("Valeur trouvee $numseq",2);
#		}
#		$sth->finish;
#		$numseq++;
	debug(" Restore sequence $sequence to value $LISTESEQUENCEURSAVED{sequence}",2);
	$sth = $dbh->prepare("create sequence $sequence start with $LISTESEQUENCEURSAVED{sequence}") || die "Unable to prepare query:".$dbh->err.", ".$dbh->errstr;
	$sth->execute || die "Unable to execute query:".$dbh->err.", ".$dbh->errstr;
	$sth->finish;
	return 1;
}

#------------------------------------------------------------------------------
# Function:     Send a HTTP request and get HTML result
# Parameters:	HTTP method (GET or POST), URL string
# Return:		O Error, 1 OK, 2 Need a redirection
# Input var:	$HTTPcookie $HTTPheader $HTTPua
# Output var:	$HTTPResponse=Long string with all HTML code content
#               $HTTPResponseWithHeader=Long string with all HTTP code content
#------------------------------------------------------------------------------
sub Get_Page()
{
	my $method = shift; 
	my $url = shift; 
	debug("Execute HTTP request (method=$method, url=$url)",3);
	my $request; my $response;

	# method=GET
	if ($method =~ /get/i) {
		$request = HTTP::Request->new(GET => $url, $HTTPheader);
		#print $request->as_string();
		$HTTPcookie->add_cookie_header($request);
		$response = $HTTPua->request($request);
		$HTTPcookie->extract_cookies($response);
		#print $response->as_string();
	}

	# method=POST enctype="application/x-www-form-urlencoded"
	if ($method =~ /post/i) {
		if ($url =~ /^(.*)\?(.*)$/) {
			$url = $1;
			my $postparams=$2;
			$request = HTTP::Request->new(POST => "$url", $HTTPheader, $postparams );
		}
		else {
			$request = HTTP::Request->new(POST => "$url", $HTTPheader);
		}
		$HTTPcookie->add_cookie_header($request);
		#print $request->as_string();
		#$response = $HTTPua->request(POST "$url", [ EMAIL => 'aaa.com' ], $HTTPheader);
		$response = $HTTPua->request($request);
		$HTTPcookie->extract_cookies($response);
		#print $response->as_string();
		if ($response->as_string() =~ /Location: ([^\s]+)/) {
			$Location=$1;
			return 302;
		}
	}
	# method=POST enctype="multipart/form-data"
	if ($method =~ /post/i) {
		
	}

	# save result
	if ($response->is_error())
	{
		$response->error_as_HTML();
		$HTTPResponseWithHeader=$HTTPResponse=$response->status_line;
		#$HTTPResponse =~ s/[\r\n]+//g;
		return 0;
	}
	$HTTPResponseWithHeader=$response->as_string();
	$HTTPResponse=$response->content();
	#$HTTPResponse =~ s/[\r\n]+//g;
	return 1;
}

#------------------------------------------------------------------------------
# Function:   Return a string with current date/time 
# Parameters: -
# Return:     Current date time with format YYYY/MM/DD-HH:MM:SS:ms
# Input var:  -
# Output var: $delay (time between this call and previous one)
#------------------------------------------------------------------------------
sub showtime() {
	my ($seconds, $microseconds) = gettimeofday;
	if ($savseconds) {$delay=($seconds-$savseconds)*1000+($microseconds-$savmicroseconds)/1000; }
	else {$delay=0; }
	$savseconds=$seconds;$savmicroseconds=$microseconds;
	my ($nowsec,$nowmin,$nowhour,$nowday,$nowmonth,$nowyear,$nowwday,$nowyday,$nowisdst) = localtime($seconds);
	$nowyear+=1900;++$nowmonth;
	return sprintf("%04d/%02d/%02d-%02d:%02d:%02d:%03d",$nowyear,$nowmonth,$nowday,$nowhour,$nowmin,$nowsec,$microseconds/1000);	
}

#------------------------------------------------------------------------------
# Function:     Wait for delay value (wait a key if parameter is -1)
# Parameters:	-1|0|n=delay
# Return:		-
# Input var:	-
# Output var:	-
#------------------------------------------------------------------------------
sub waitkey()
{
	my $bidon;
	if ($DELAY < 0) { print "$Message{'waitkey'}"; read STDIN, $bidon, 1; }
	else { sleep $DELAY; }
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
# Function:     
# Parameters:	string
# Return:		string
# Input var:	-
# Output var:	-
#--------------------------------------------------------------------
sub FormatRegex {
	my $string=shift;
	$string =~ s/\s/\\s/g;
	return $string;
}

#--------------------------------------------------------------------
# Function:     Print a message in output file
# Parameters:	string_to_print  [number_of_space_for_indent]
# Return:		0
# Input var:	-
# Output var:	-
#--------------------------------------------------------------------
sub WriteOutput {
	my $stringtoprint=shift||"";
	my $decal=shift||0;
	my $ident="";
	#foreach my $key (1..$decal) { $ident.=" "; }
	print OUTPUTFILE "$ident$stringtoprint\n";
	if ($Verbose) { print "$ident$stringtoprint\n" };
	return 0;
}

#--------------------------------------------------------------------
# Function:     Save a html file with a content
# Parameters:	html_content_string  [html_filename]
# Return:		0
# Input var:	-
# Output var:	-
#--------------------------------------------------------------------
sub WriteHTML {
	my $htmlcontentstring=shift||"";
	my $htmlfilename=shift||"${ConfigFile}".($ID?".$$":"").".lasterror.html"; $htmlfile =~ s/^.*[\\\/]+([^\\\/]+)$/$1/;
	open(HTMLFILE,">$OutputDir/$htmlfilename");
	print HTMLFILE "$htmlcontentstring\n";
	close HTMLFILE;
	return 0;
}

#--------------------------------------------------------------------
# Function:     Open connexion to database if not already opened
# Parameters:	-
# Return:		0
# Input var:	$BASEENGINE, $DSN, $USERBASE, $PASSWORDBASE
# Output var:	$dbh
#--------------------------------------------------------------------
sub OpenConnect {
	debug("Connexion base ($BASEENGINE, $DSN, $USERBASE, $PASSWORDBASE)",1);
	$dbh = DBI->connect("dbi:$BASEENGINE:$DSN", "$USERBASE", "$PASSWORDBASE", { PrintError => 0, RaiseError => 0, AutoCommit => 1 } ) || error("Failed to connect dbi:$BASEENGINE:$DSN");
	return 0;
}

#--------------------------------------------------------------------
# Function:     Open connexion to database if not already opened
# Parameters:	-
# Return:		0
# Input var:	$dbh
# Output var:	-
#--------------------------------------------------------------------
sub CloseConnect {
	if ($dbh) {
		# Deconnexion base
		debug("Disconnect base",1);
		$dbh->disconnect;
	}
	return 0;
}

#--------------------------------------------------------------------
# Function:     Execute pre or post actions
# Parameters:	action string
# Return:		0 OK, 1 Error
# Input var:	-
# Output var:	-
#--------------------------------------------------------------------
sub ExecutePrePostActions {
	my $action=shift;
	my ($command,$value)=split(/\s+/,$action,2);
	&debug("$command $value",1);
	# action is SEQUENCE
	if ($command =~ /^sequence/i) {
		OpenConnect();
		my ($seqname,$seqvalue)=split(/\s+/,$value);
 		$seqname=eval("$seqname");
 		$seqvalue=eval("$seqvalue");
		$ret=set_sequence($seqname,$seqvalue);
		if ($ret) { 
			&WriteOutput("---> Error: Failed to set sequence $seqname to $seqvalue");
			return 1;
		}
		else {
			&WriteOutput("SEQUENCE $seqname set to $seqvalue");
		}
	}
	# action is SQL
	if ($command =~ /^sql/i) {
		$value=eval("$value");
		if ($value  =~ /^DELETE/i || $value  =~ /^INSERT/i) {
			OpenConnect();
			&debug("Execute request $value",1);
			my $sth = $dbh->prepare($value);
			if (! $sth) {
				&WriteOutput("---> Error: Failed to prepare $value:".$dbh->err.", ".$dbh->errstr);
				return 1;
			}
			if (! $sth->execute) {
				&WriteOutput("---> Error: Failed to execute $value:".$dbh->err.", ".$dbh->errstr);
				return 1;
			}
			$sth->finish;
			&WriteOutput("$value");
		}
	}
	# action is SCRIPT
	if ($command =~ /^script/i) {
 		$value=eval("$value");
		my $ret=&RunScript($value);
		if ($ret) {
			&WriteOutput("---> Error: Failed to execute $value : $ret");
			return 1;
		}
	}
	return 0;
}

#--------------------------------------------------------------------
# Function:     Run a script and wait until its end
# Parameters:	script name
# Return:		0 OK, "Return code=0" if error
# Input var:	-
# Output var:	-
#--------------------------------------------------------------------
sub RunScript {
	my $script=shift;
	&debug("RunScript $script 2>&1",1);
	my $output=`$script 2>&1`;
	if ($! || ($?>>8)) {
		$rc=($?>>8);
	}
	else {
		$rc=$?;
	}
	if ($rc) { return "Return code=$rc".($!?",$!":""); }
	return 0;
}


#--------------------------------------------------------------------
# Function:     Loop on action array
# Parameters:	ActionsTypeInit, ActionsValueInit, level, levelmax
# Return:		0 OK
# Input var:	-
# Output var:	-
#--------------------------------------------------------------------
sub LoopOnActionArray {
	my $refarray=shift;
	my @ActionsTypeArray=@$refarray;
	my $refarray=shift;
	my @ActionsValueArray=@$refarray;
	my $level=shift||0;
	my $levelmax=shift||0;

	&debug("LoopOnActionArray ".@ActionsTypeArray." ".@ActionsValueArray." $level $levelmax",2);
	foreach my $actionnb (1..(@ActionsTypeArray-1))
	{
		# Write last result if action is WRITETO or WRITETOH
		if ($ActionsTypeArray[$actionnb] =~ /writeto/i) {
			my $file=eval($ActionsValueArray[$actionnb]);
			if ($ID) { $file.=".$$"; }
			if ($ActionsTypeArray[$actionnb] =~ /writetoh/i) {
				debug("Write last output with HTTP header to file \"$file\"",3);
				&WriteHTML($HTTPResponseWithHeader,$file);
			}
			else {
				debug("Write last output to file \"$file\"",3);
				&WriteHTML($HTTPResponse,$file);
			}
			next;
		}

		# Call URL if action is AUTO
		if ($ActionsTypeArray[$actionnb] =~ /auto/i) {

			my $datedebut=showtime();			# Call to initialize datedebut of delay counter
			#&WriteOutput("$datedebut AUTO START",$level);

			if ($lasturlinerror) { 
				&WriteOutput("---> Error: Can't make auto HTTP request because last URL request failed",$level);
				if (! $NoStopIfError) { last; }
				next;
			}
			if (! $HTTPResponse) { 
				&WriteOutput("---> Error: Can't make auto HTTP request because no previous HTML page was returned",$level);
				if (! $NoStopIfError) { last; }
				next;
			}
	
			# Loop on each URL to search GET requests
			my $text=$HTTPResponse;
			my @newActionsType=();
			my @newActionsValue=();
			while ($text =~ /href=([^\s\>]+)/i) {
				my $savurl=$1;
				$text = $';
				my $url=$savurl; $url =~ s/^[\'\"]//; $url =~ s/[\'\"]$//;
				if ($url =~ /^\//) {
					$url="http://$SERVER$url"; 
				}
				else {
					# TODO build url from relative path
					$url="http://$SERVER/jsp/$url"; 
					#$url="xxx$url";
				}
				
				&debug(" Add to AUTO list URL '$url'",3);
				push @newActionsType, "GET";
				push @newActionsValue, "\"$url\"";
			}
			# Loop on each URL to search POST requests
			# TODO

			# Send new Array
			LoopOnActionArray(\@newActionsType,\@newActionsValue,1,1);

			#&WriteOutput("$datedebut AUTO END",$level);
			next;
		}	
	
		# Call URL if action is GET or POST
		if ($ActionsTypeArray[$actionnb] =~ /get/i || $ActionsTypeArray[$actionnb] =~ /post/i) {
			
			# Wait delay
			if ($NbOfRequestsSent || $DELAY < 0) {	# No wait for first access
				if ($Verbose) { &WriteOutput(""); }
				elsif ($NbOfRequestsSent && $DELAY < 0) { print "\n"; }
				&waitkey();			
			}
	
			# Sent request
			$NbOfRequestsSent++;
			my $datedebut=showtime();			# Call to initialize datedebut of delay counter
			
			# Process request and get result
			my $url=eval($ActionsValueArray[$actionnb]);
			if (! $level) { &WriteOutput("$datedebut URL $NbOfRequestsSent - $url",$level); }
			else { &WriteOutput("$datedebut URL $NbOfRequestsSent (AUTO $level) - $url",$level); }
			my $result = &Get_Page($ActionsTypeArray[$actionnb],$url);
			my $noinfiniteloop=0;
			while ($result eq 302 && $noinfiniteloop < 10) {
				$noinfiniteloop++;
				# Here $Location contains "/newdir/newpage.html"
				$url =~ /^http[s]:\/\/([^\\\/]*)/i;
				my $serverbase=$1;
				$result=&Get_Page("GET","http://$serverbase$Location");
			}	
	
			# Check result
			$lasturlinerror=0;
			if ($noinfiniteloop >= 10) {
				&WriteOutput("---> Error: HTTP error: HTTP header always contains a redirection",$level);
				&WriteHTML($HTTPResponse);
				$lasturlinerror=1;
				$ActionsDuration{$NbOfRequestsSent}=-1;
				if (! $NoStopIfError) { last; }
				next;
			}
			if (! $result) {
				&WriteOutput("---> Error: HTTP error: $HTTPResponse",$level);
				&WriteHTML($HTTPResponse);
				$lasturlinerror=1;
				$ActionsDuration{$NbOfRequestsSent}=-1;
				if (! $NoStopIfError) { last; }
				next;
			}
	
			# Load image links
			if ($LoadImages) {
				# TODO appeler images
	
			}
	
			# Load durations
			my $datefin=showtime();
			$ActionsDuration{$NbOfRequestsSent}=$delay;			# Save delay for page $NbOfRequestsSent
			if (! $ActionsMinDuration || ! $ActionsDuration{$ActionsMinDuration} || $ActionsDuration{$NbOfRequestsSent}<$ActionsDuration{$ActionsMinDuration}) { $ActionsMinDuration=$NbOfRequestsSent; }
			if (! $ActionsMaxDuration || $ActionsDuration{$NbOfRequestsSent}>$ActionsDuration{$ActionsMaxDuration}) { $ActionsMaxDuration=$NbOfRequestsSent; }
	
			if ($NbOfRequestsSent && ! $Verbose && ! $Silent) { print "."; }
			if ($NbOfRequestsSent && ! $lasturlinerror) {
				# Show OK output for previous url test
				&WriteOutput("---> OK - ".($ActionsDuration{$NbOfRequestsSent})." ms",$level);
			}
			next;
		}
		
		# Check last call if action is CHECKYES
		if ($ActionsTypeArray[$actionnb] =~ /checkyes/i) {
			$CheckYesTotal{$NbOfRequestsSent}++;
			if (! $lasturlinerror) {
				# Teste si reponse contient chaine reponse du tableau des URL
				my $match=eval($ActionsValueArray[$actionnb]);
				$match=FormatRegex($match);
				debug("Check if answer contains \"$match\"",2);
				if ($HTTPResponse !~ /$match/i) {
					&WriteOutput("---> Error: Can't find CHECKYES criteria \"$match\"",$level);
					&WriteHTML($HTTPResponse);
					$lasturlinerror=1;
					if (! $NoStopIfError) { last; }
				}
				else { $CheckYesOk{$NbOfRequestsSent}++; }
			}
			next;
		}
	
		# Check last call if action is CHECKNO
		if ($ActionsTypeArray[$actionnb] =~ /checkno/i) {
			$CheckNoTotal{$NbOfRequestsSent}++;
			if (! $lasturlinerror) {
				# Teste si reponse contient chaine reponse du tableau des URL
				my $match=eval($ActionsValueArray[$actionnb]);
				$match=FormatRegex($match);
				debug("Check if answer does not contain \"$match\"",2);
				if ($HTTPResponse =~ /$match/i) {
					&WriteOutput("---> Error: Found CHECKNO criteria \"$match\"",$level);
					&WriteHTML($HTTPResponse);
					$lasturlinerror=1;
					if (! $NoStopIfError) { last; }
				}
				else { $CheckNoOk{$NbOfRequestsSent}++; }
			}
			next;
		}
	
		# Get var if action is VAR
		if ($ActionsTypeArray[$actionnb] =~ /var/i) {
			if (! $lasturlinerror) {
				# On recupere valeur de la page de reponse
				my $variable=$ActionsValueArray[$actionnb]; $variable =~ s/:.*//; $variable =~ s/^\"//;
				my $match=$ActionsValueArray[$actionnb];
				while ($match =~ /\$PARAM(\d+)/) {
					my $paramname="PARAM$1";
					my $valparam=$$paramname;
					$match =~ s/\$$paramname/$valparam/g;
				}
				$match =~ s/^.*://; $match =~ s/\"$//;
				$match=FormatRegex($match);
				debug("Catching variable=\"$variable\" matching match=\"$match\"",2);
				if ($HTTPResponse =~ /$match/) 
				{
					$$variable=$1;
					debug(" Found var $variable=$$variable",2);
				}
				else
				{
					&WriteOutput("---> Error: Variable $variable can't be extracted",$level);
					&WriteHTML($HTTPResponse);
					$lasturlinerror=1;
					if (! $NoStopIfError) { last; }
				}
			}
			next;
		}
	
		# Run script if action is SCRIPT
		if ($ActionsTypeArray[$actionnb] =~ /script/i) {
			# On recupere valeur de la page de reponse
			my $script=eval($ActionsValueArray[$actionnb]);
			my $ret=&RunScript($script);
			if ($ret) {
				&WriteOutput("---> Error: Failed to execute $script : $ret",$level);
				if (! $NoStopIfError) { last; }
			}
			next;
		}
	
		&WriteOutput("Config file error: Unknown action $ActionsTypeArray[$actionnb]",$level);
	
	}

	return;
}




#--------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------
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
$BotName=ucfirst($PROG);

# Define QueryString (string with all parameters)
$QueryString=""; for (0..@ARGV-1) {
	#if ($_ > 0) { $QueryString .= "&"; }
	$QueryString .= "&";
	my $NewLinkParams=$ARGV[$_]; $NewLinkParams =~ s/^-+//; $NewLinkParams =~ s/\s/%20/g;
	$QueryString .= "$NewLinkParams";
}

# Get config file name
if ($QueryString =~ /&debug=(\d+)/i)		{ $Debug=$1; }
if ($QueryString =~ /&config=([^\s&]+)/i)	{ $ConfigFile=&DecodeEncodedString($1); }
if ($ARGV[0] eq "-h" || ! $ConfigFile) {
	print "----- $PROG $VERSION -----\n";
	print "Advanced Web Bot is a tool to test a web server.\n";
	print "Usage: $PROG.$Extension -config=testconfigfile [options]\n";
	print "\n";
	print "Where options are:\n";
	print "  -server=xxx         Overwrite SERVER value of testconfig file.\n";
	print "  -user=xxx           Overwrite USER value of testconfig file.\n";
	print "  -password=xxx       Overwrite PASSWORD value of testconfig file.\n";
	print "  -delay=n            Overwrite DELAY value of testconfig file.\n";
	print "  -timeout=n          Overwrite TIMEOUT value of testconfig file.\n";
	print "  -loadimages         Load image files.\n";
	print "  -nostopiferror      $BotName continues with next test when an error occurs.\n";
	print "  -prepareonly        Only execute pre-actions.\n";
	print "  -executeonly        Do not execute any pre-actions nor post-actions.\n";
	print "  -id                 Output file name contains process ID number.\n";
	print "  -verbose            Output file is also reported on std output (screen).\n";
	print "  -silent             Nothing on std output (screen).\n";
	print "  -debug=X            To add debug informations lesser than level X\n";
	print "\n";
	print "Now supports/detects:\n";
	print "  Several predefined post-test or pre-test actions (Scripts, SQL request...)\n";
	print "  Web sites with Basic HTTP/Proxy authentication\n";
	print "  Easy to configure (one config file)\n";
	print "  Configuration and Test plan can be defined dynamically (using variables\n";
	print "    catched from a previous test)\n";
	print "  Possible use of several simultanous sessions (with ${PROG}launch.pl)\n";
	sleep 3;
	exit 1;
}

# Overwrite testconfig file with parameters
if ($QueryString =~ /&startsession=(\d+)/i) { $STARTSESSION=$1; }
if ($QueryString =~ /&numsession=(\d+)/i)   { $NUMSESSION=$1; }
if ($QueryString =~ /&nbsessions=(\d+)/i)	{ $NBSESSIONS=$1; }

# Read config file
if (! $ConfigFile) { $ConfigFile="$PROG.conf"; }
Read_Config_File();

# Check config file
if (! -d "$OutputDir") {
	&error("Output directory '$OutputDir' does not exists or is not writeable. You need to create this directory for using $PROG (directory required to store $BotName ouput).\n");
}

# Overwrite testconfig file with parameters
if ($QueryString =~ /&server=([^\s&]+)/i)   { $SERVER=&DecodeEncodedString($1); }
if ($QueryString =~ /&user=([^\s&]+)/i)	    { $USER=&DecodeEncodedString($1); }
if ($QueryString =~ /&password=([^\s&]+)/i) { $PASSWORD=&DecodeEncodedString($1); }
if ($QueryString =~ /&delay=(\d+)/i)        { $DELAY=$1; }
if ($QueryString =~ /&timeout=(\d+)/i)      { $TIMEOUT=$1; }
if ($QueryString =~ /&loadimages/i)		    { $LoadImages=1; }
if ($QueryString =~ /&nostopiferror/i)	    { $NoStopIfError=1; }
if ($QueryString =~ /&prepareonly/i)	    { $PrepareOnly=1; }
if ($QueryString =~ /&executeonly/i)	    { $ExecuteOnly=1; }
if ($QueryString =~ /&id/i)				    { $ID=1; }
if ($QueryString =~ /&verbose/i)		    { $Verbose=1; }
if ($QueryString =~ /&silent/i)			    { $Silent=1; }

# Define output file
my $conffile=$ConfigFile; $conffile =~ s/^.*[\\\/]+([^\\\/]+)$/$1/;
if ($ID) {
	$OutputFile="$OutputDir/$conffile.$$.out";
}
else {
	$OutputFile="$OutputDir/$conffile.out";
}

# Read language file
&Read_Language_Data($Lang);

# Check Message files
if (! $Message{"teststart"}) { $Message{"teststart"}=ucfirst($PROG)." $VERSION started for config/test file $ConfigFile"; }
if (! $Message{"waitkey"}) { $Message{"waitkey"}="Press a key to start next HTTP request"; }
if (! $Message{"testend"}) { $Message{"testend"}="Test finished. Results are available in file $OutputFile"; }
if (! $Message{"prepareend"}) { $Message{"prepareend"}="Prepare actions done. Results are available in file $OutputFile"; }

# Affecte les variables dynamiquement si elles dependent de données
# en base, pour PARAM1 à PARAM99
init_var();

# Open output file
debug("Open output file $OutputFile",1);
open(OUTPUTFILE,">$OutputFile") || error("Failed to open output file $OutputFile");

if ($Verbose) { &WriteOutput(""); }
elsif (! $Silent) { print "$Message{'teststart'}\n"; }

&WriteOutput("TEST $PROG $VERSION");
&WriteOutput("---------------------------");
&WriteOutput("Config file: $ConfigFile");
&WriteOutput("Server: $SERVER - User: $USER - Delay: $DELAY");
&WriteOutput("Botname: $BotName - TimeOut: $TIMEOUT - MaxSize: $MaxSize");
&WriteOutput("Date: $nowyear-$nowmonth-$nowday $nowhour:$nowmin:$nowsec");
&WriteOutput("Process ID: $$");
&WriteOutput("");

# Def of $HTTPheader $HTTPua $HTTPcookie
$HTTPheader = new HTTP::Headers;  
if ($USER) { $HTTPheader->authorization_basic($USER,$PASSWORD); }	# ???????? A virer si pb
$HTTPcookie = HTTP::Cookies->new(file=>"cookies$$.dat");
$HTTPua = LWP::UserAgent->new();
if ($ID) { $HTTPua->agent("$BotName/$VERSION - Session $NUMSESSION (PID $$) - " . $HTTPua->agent); }
else { $HTTPua->agent("$BotName/$VERSION-" . $HTTPua->agent); }
if ($TIMEOUT) { $HTTPua->timeout($TIMEOUT); }
if ($MaxSize) { $HTTPua->max_size($MaxSize); }
if ($PROXYSERVER) {
	# set proxy for access to external sites
	$HTTPua->proxy(["http","https"],$PROXYSERVER);
	# avoid proxy for these hosts
	$HTTPua->no_proxy(@HOSTSNOPROXY);
}


#----------------------
# PRE ACTIONS
#----------------------

if (! $ExecuteOnly) {
	&WriteOutput("PRE ACTIONS");
	&WriteOutput("---------------------------");

	# Launch pre actions
	foreach my $action (@PREACTIONS)
	{
		if (&ExecutePrePostActions($action)) {
			# Error in pre-post command
			error("Error: A command in PREACTIONS section failed.");
		}
	}
}
if ($PrepareOnly) {
	if (! $Verbose && ! $Silent) { print "$Message{'prepareend'}\n"; }
	CloseConnect();
	exit 0;
}
&WriteOutput("");


#----------------------
# ACTIONS
#----------------------

&WriteOutput("ACTIONS");
&WriteOutput("---------------------------");
$lasturlinerror=0;

&LoopOnActionArray(\@ActionsTypeInit,\@ActionsValueInit,0,0);
&WriteOutput("");


#----------------------
# POST ACTIONS
#----------------------

if (! $ExecuteOnly) {
	&WriteOutput("POST ACTIONS");
	&WriteOutput("---------------------------");

	# Restore changed sequences
	if (scalar keys %LISTESEQUENCEURSAVED) {
		foreach my $sequence (keys %LISTESEQUENCEURSAVED) {
			if ($LISTESEQUENCEURSAVED{$sequence}) {
				# Restore sequence value if saved with a value not ""
				restore_sequence($sequence);
			}
		}
	}

	# Launch post actions
	foreach my $action (@POSTACTIONS)
	{
		&ExecutePrePostActions($action);
	}

	&WriteOutput("");
}


#----------------------
# SUMMARY
#----------------------
$NbOfRequestsReturnedSuccessfull=0;
$RequestDuration=0;
#foreach my $actionnb (1..(@ActionsTypeInit-1)) {
foreach my $requestnb (1..$NbOfRequestsSent) {
	if ($ActionsDuration{$requestnb} && $ActionsDuration{$requestnb} > 0) {
		$NbOfRequestsReturnedSuccessfull++;
		$RequestDuration+=$ActionsDuration{$requestnb};
	}
	$TotalCheckYesOk+=$CheckYesOk{$requestnb};
	$TotalCheckYesTotal+=$CheckYesTotal{$requestnb};
	$TotalCheckNoOk+=$CheckNoOk{$requestnb};
	$TotalCheckNoTotal+=$CheckNoTotal{$requestnb};
}

&WriteOutput("SUMMARY");
&WriteOutput("---------------------------");
&WriteOutput("Total requests to do: $NbOfUrlInit".($NbOfAutoInit?" (+AUTO)":""));
&WriteOutput("Total requests sent: $NbOfRequestsSent ($NbOfRequestsReturnedSuccessfull answered)");
if ($RequestDuration > 0) { &WriteOutput("Total requests duration: $RequestDuration ms"); }
else { &WriteOutput("Total requests duration: -"); }
if ($RequestDuration > 0) { &WriteOutput("Average requests response time: ".int($RequestDuration/($NbOfRequestsReturnedSuccessfull||1))." ms/request"); }
else { &WriteOutput("Average requests response time: -"); }
&WriteOutput("Total Check Yes: $TotalCheckYesOk/$TotalCheckYesTotal  No: $TotalCheckNoOk/$TotalCheckNoTotal");
if ($ActionsMinDuration) { &WriteOutput("Faster request response time: URL ".sprintf("%3d",$ActionsMinDuration)." - ".sprintf("%4d",$ActionsDuration{$ActionsMinDuration})." ms"); }
else { &WriteOutput("Faster request response time: -"); }
if ($ActionsMaxDuration) { &WriteOutput("Slower request response time: URL ".sprintf("%3d",$ActionsMaxDuration)." - ".sprintf("%4d",$ActionsDuration{$ActionsMaxDuration})." ms"); }
else { &WriteOutput("Slower request response time: -"); }
my $cumul=0;
#foreach my $requestnb (1..(@ActionsTypeInit-1)) {
foreach my $requestnb (1..$NbOfRequestsSent) {
	my $delay=$ActionsDuration{$requestnb};
	if ($delay > 0) {
		my $urlresult=sprintf("URL %3d - ",$requestnb);
		$cumul+=$ActionsDuration{$requestnb};
		$urlresult.=sprintf("Duration: %4d ms - ",$delay);
		$urlresult.=sprintf("Cumul: %4d ms - ",$cumul);
		$urlresult.=sprintf("Check Yes:%2d /%2d No:%2d /%2d",$CheckYesOk{$requestnb},$CheckYesTotal{$requestnb},$CheckNoOk{$requestnb},$CheckNoTotal{$requestnb});
		&WriteOutput($urlresult);
	}
	elsif ($delay < 0) {
		my $urlresult=sprintf("URL %3d - ",$requestnb);
		$urlresult.=sprintf("Duration: Failed");
		&WriteOutput($urlresult);
	}
}


close OUTPUTFILE;

# End bot
if (! $Verbose && ! $Silent) { print "\n$Message{'testend'}\n"; }
if ($Wait) {
	my $bidon;
	print "Entree pour quitter"; read STDIN, $bidon, 1;
}

0;
