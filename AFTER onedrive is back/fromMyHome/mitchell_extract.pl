#!/usr/local/bin/perl -w
#$Id: mitchell_extract.pl,v 1.2 2025/10/03 14:41:15 rj132422 Exp rj132422 $   
print "\n" . "##################################################################################";
print "\n" . "#  PROCNAME:   mitchell_extract.pl                                                     #";
print "\n" . "#  JOB DESCRIPTION:   MITCHELL UM/Ceg Data Extract                                #";
print "\n" . "##################################################################################";
use File::Basename;
use File::Copy;
use Getopt::Long;
use Mail::Sendmail;

#2019/10/11 PAG - replaced for SFTP
#use Net::FTP;
use Net::SFTP::Foreign;

use DBI;

# for testing
# DBI->trace(9,"/home/pg2697/mitchell_trace");
# for testing


$STEPNAME = "STEP010"; 
     print "\n" . "Start " . $STEPNAME . " Declare Prototypes & Initialize Variables  " . `date`;
#******************************************************************************
# Declare Prototypes  &  Initialize Variables                                 *
#                                                                             *
# For Restartability:                                                         *
# 1. Define the variables used in multiple steps prior to first restart step. *
# 2. Clearly define each restartable step/block with a perl LABEL:            *
#     e.g. STEP050R:                                                          *
#    and enclose the entire STEP in { }.                                      *
# 3. To Restart a Job at a Specific Step:                                     * #    Enter: xexm660.ksh STEPLABEL                                             *
#     e.g. xexm660.ksh STEP050R                                               *
#******************************************************************************

sub my_exit($$);
sub send_message($$);

$err_code = 0;
$result_code = 0;

## get shared global env. variables
$race = $ENV{'RACE'};
print "       " . "race is: " . $race . "\n";

## get shared global env. variables for Oracle directory objects
$obj_tmpdir = $ENV{'OBJ_TMPDIR'};
print "       " . "obj_tmpdir is: " . $obj_tmpdir . "\n";

## define UNIX server directories
$basedir = "$race"; 
$tmpdir = "$basedir/tmp";
$rptdir = "$basedir/rpt";
$datdir = "$basedir/dat";
$bindir = "$basedir/bin";
$logdir = "$basedir/log";
$prmdir = "$basedir/prm";
print "       " . "basedir is: " . $basedir . "\n";
print "       " . "tmpdir is: " . $tmpdir . "\n";
print "       " . "rptdir is: " . $rptdir . "\n";
print "       " . "datdir is: " . $datdir . "\n"; 
print "       " . "bindir is: " . $bindir . "\n";     
print "       " . "logdir is: " . $logdir . "\n";
print "       " . "prmdir is: " . $prmdir . "\n";

## define variables used in multiple steps
$jobname = $ENV{'JOBNAME'};
print "       " . "jobname is: " . $jobname . "\n";

($day,$mon,$year) = (localtime)[3,4,5];
## create remote file with customer's expected file name & embedded date stamp
$remote_filename = sprintf("mitchell_%04d%02d%02d.zip",$year+1900,$mon+1,$day);
## create zip_file name with jobname prefix and save gdg versions of the last 3 months (no date stamp)
$zip_file = "$datdir/$jobname" . "_" . "mitchell.zip";
print "       " . "remote_filename: " . $remote_filename . "\n"; 
print "       " . "zip_file: " . $zip_file . "\n";
    

$STEPNAME = "STEP020"; 
     print "\n" . "Start " . $STEPNAME . " Get Mailing List  " . `date`;
#**************************************************************************
# Get Mailing List                                                        *
#**************************************************************************

$result_code = init_message();
if ($result_code == -1) { my_exit($message,$result_code); }


$STEPNAME = "STEP030"; 
     print "\n" . "Start ". $STEPNAME . " Get DB & FTP Login Info  " . `date`;
#**************************************************************************
# Get Database Login Info & Ftp Login Info                                *
#**************************************************************************

$result_code = init();
if ($result_code == -1) { my_exit($message,$result_code); }


$STEPNAME = "STEP040"; 
     print "\n\n" . "Start " . $STEPNAME . " Get Restart STEP  " . `date`;
#**************************************************************************
# Get Command Line Argument: Restart STEP                                *
#**************************************************************************

GetOptions('restart=s' => \$restart);
if( !$restart ) { print("       No Restart STEP" . "\n"); }
else { print "       Restart At STEP: " . $restart . "\n"; 
       goto $restart;  }


STEP050R:
$STEPNAME = "STEP050R"; 
     print "\n" . "Start " . $STEPNAME . " Delete Previous Files  " . `date`;
#**************************************************************************
# Delete Previous Files  From Dat Directory                               *
#**************************************************************************

{

$filemask = "$datdir/$jobname" . "_" ."*mitchell*.dat";
print "       " . "files to delete\n";
print `ls -l $filemask`;

$err_code =  unlink glob("$filemask");
if ($err_code == 0) { print "       " . "No Files to Delete: " . "$filemask " . `date`; }
else {  print "       " . "Deleted Previous Files: " . "$filemask " . `date`; } 

}


STEP060R:
$STEPNAME = "STEP060R"; 
     print "\n" . "Start " . $STEPNAME . " ORA Extract Files    " . `date`;
#**************************************************************************
# Extract Mitchell Files                                                  *
#**************************************************************************

{
$err_code = extract_files();

if ($err_code == -1) { 
   my_exit($message,$err_code);
                     }

##list of newly extracted files 
$filemask = "$tmpdir/mitchell*.txt";
print "       " . "extracted tmp files\n";
print `ls -l $filemask`;
print "End  ". $STEPNAME . " ORA Extract Files  " . `date`;

}

STEP070R:
$STEPNAME = "STEP070R"; 
     print "\n" . "Start " . $STEPNAME . " Zip Extracted Files  " . `date`;
#**************************************************************************
# Zip Mitchell Extracted Files                                            *
#**************************************************************************

{

## Note: $result_code for zip stmt below = 3072 when no files in dir to zip. 
##       3072 when divided by 256 = 12 the unix aix zip utility's return code for "zip error: Nothing to do!"
##       This text message auto prints when zip can't find the files even w/q option. 
##       A non zero zip status code is divided by 256 to get the true zip utility status codes
##       See man zip.

$filemask = "mitchell*.txt";
if ( !chdir $tmpdir ){ $message = ("Error: unable to chdir to $tmpdir");
                       $err_code = -1;
                       my_exit($message,$err_code); }
                       
print "       " . "changed dir to $tmpdir" . "\n";

$result_code = system "zip -q $zip_file $filemask";
if ($result_code != 0) { $result_code = $result_code / 256;
                         my_exit("Error: unable to create zip file $zip_file Status Code is",$result_code); }
else { print "       " . "Created " . $zip_file . "\n"; 
       print "End  ". $STEPNAME . " Zip Extracted Data Files " . `date`; }


}


STEP075R:
$STEPNAME = "STEP075R"; 
     print "\n" . "Start " . $STEPNAME . " Copy Extract Mitchell Files    " . `date`;
#**************************************************************************
# Copy Extract Mitchell Files  to dat                                     *
#**************************************************************************

{

$source = "$tmpdir/mitchell_service.txt";
$dest = "$datdir/$jobname" . "_" . "mitchell_service.dat";
if (copy($source, $dest) == 0) {
    $message = ("Error: unable to copy $source to $dest");
    $err_code = -1;
    my_exit($message,$err_code); }

$source = "$tmpdir/mitchell_ymm.txt";
$dest = "$datdir/$jobname" . "_" . "mitchell_ymm.dat";	
if (copy($source, $dest) == 0) {
    $message = ("Error: unable to copy $source to $dest");
    $err_code = -1;
    my_exit($message,$err_code); }

$source = "$tmpdir/mitchell_master.txt";
$dest = "$datdir/$jobname" . "_" . "mitchell_master.dat";	
if (copy($source, $dest) == 0) {
    $message = ("Error: unable to copy $source to $dest");
    $err_code = -1;
    my_exit($message,$err_code); }
		

$source = "$tmpdir/mitchell_note.txt";
$dest = "$datdir/$jobname" . "_" . "mitchell_note.dat";	
if (copy($source, $dest) == 0) {
    $message = ("Error: unable to copy $source to $dest");
    $err_code = -1;
    my_exit($message,$err_code); }
		

$source = "$tmpdir/mitchell_note_xref.txt";
$dest = "$datdir/$jobname" . "_" . "mitchell_note_xref.dat";	
if (copy($source, $dest) == 0) {
    $message = ("Error: unable to copy $source to $dest");
    $err_code = -1;
    my_exit($message,$err_code); }
		

$source = "$tmpdir/mitchell_prtc_body.txt";
$dest = "$datdir/$jobname" . "_" . "mitchell_prtc_body.dat";	
if (copy($source, $dest) == 0) {
    $message = ("Error: unable to copy $source to $dest");
    $err_code = -1;
    my_exit($message,$err_code); }
		

$source = "$tmpdir/mitchell_ref_detail.txt";
$dest = "$datdir/$jobname" . "_" . "mitchell_ref_detail.dat";	
if (copy($source, $dest) == 0) {
    $message = ("Error: unable to copy $source to $dest");
    $err_code = -1;
    my_exit($message,$err_code); }
		

$source = "$tmpdir/mitchell_ref_overlap.txt";
$dest = "$datdir/$jobname" . "_" . "mitchell_ref_overlap.dat";	
if (copy($source, $dest) == 0) {
    $message = ("Error: unable to copy $source to $dest");
    $err_code = -1;
    my_exit($message,$err_code); }

#Added in 1.7 - AES-3143 - Added change so that the new file "mitchell_chrome_xref.txt" gets saved under bin/dat as "mitchell_chrome_xref.dat".
$source = "$tmpdir/mitchell_chrome_xref.txt";
$dest = "$datdir/$jobname" . "_" . "mitchell_chrome_xref.dat";
if (copy($source, $dest) == 0) {
    $message = ("Error: unable to copy $source to $dest");
    $err_code = -1;
    my_exit($message,$err_code); }

$filemask = "$datdir/$jobname" . "*mitchell*.dat";
print "       " . "copied extracted dat files\n";
print `ls -l $filemask`;
print "End  ". $STEPNAME . " Rename/copy Extract Mitchell Files  " . `date`;
    
}


STEP080R:
$STEPNAME = "STEP080R"; 
     print "\n" . "Start " . $STEPNAME . "  FTP Zip File to FTP Server " . `date`;
#**************************************************************************
# # Place Zip file on Mitchell's sftp server                              *
#**************************************************************************

{

## NOTE: In DEV: if file exists in /outgoing directory - ftp put abends - does not overwrite!!!
##       In PROD: latest file overwrites previous file in prod server folder

#2019/10 PAG - replaced ftp with sftp
my $sftp = sftp_connect();

## ftp file with date stamp -> yyyymmdd
#print "\nSource File= $zip_file \n"; 
#print "\nRemote File= $remote_filename \n"; 
if (!$sftp->put($zip_file,$remote_filename)) {
               $err_code = -1; }
$sftp->disconnect;

if ($err_code == -1) 
     { my_exit("Error: unable to sftp->put $zip_file",$err_code); }
else { print "       " . "Good SFTP of " . $zip_file . " to " . $ftp_site . " " . $ftp_path ." " . $remote_filename  . "\n";
      }

}


STEP085R:
$STEPNAME = "STEP085R"; 
     print "\n" . "Start " . $STEPNAME . "  Save 3 Versions of the Zip File " . `date`;
#**************************************************************************
# # Save 3 Versions of the Zip File - use setgdg.ksh                                      *
#**************************************************************************
{

$source = "$zip_file";
$gdgdest = `setgdg.ksh "$source(+01)" "NEW" "3"`; 
chomp $gdgdest;

if (move($source, $gdgdest) == 0) 
   { $message = ("Error: unable to move $source to $gdgdest");
     my_exit($message,"-1"); }
else  { print ("       " . "moved $source to $gdgdest","\n"); }                     

}

STEP090R:
$STEPNAME = "STEP090R"; 
     print "\n" . "Start " . $STEPNAME . " Email Notification Zip File Ready " . `date`;
#**************************************************************************
# email notification to appropriate parties                               *
#**************************************************************************

send_message("Latest Mitchell data ($remote_filename) is available on Mitchell's ftp site.","");

STEP999R:
$STEPNAME = "STEP999R"; 
     print "\n" . "Start " . $STEPNAME . "    " . `date`;
#**************************************************************************
# end of job delete temporary files & exit                                                       *
#**************************************************************************

{

 $filemask = "$tmpdir/mitchell*.txt";
 $err_code =  unlink glob("$filemask");
 if ($err_code == 0) { print "Error No Files Deleted: " . "$filemask" . "\n"; }
 else {  print "       " . "Deleted tmp Files: " . "$filemask " . `date`; } 

exit;

}

######################################################
# subroutines
######################################################
# initialize database, ftp and mailing list.
sub init 
{
  $prmfile = "$prmdir/zextdbipass.prm";
  unless (open $input, "$prmfile") {
          $message = ("Error subr init: can't open database login info: $!");
          return -1;               }
  print "       " . "subr init: good open database info" . "    " . `date`;

  ## get first line in parm file -> db login info
  $line = <$input>;
  ($database, $username, $m_password) = split(" ", $line);

  if (!$database || !$username || !$m_password) {
      $message = ("Error subr init: database info is incorrect or corrupt");
      close($input);
      return -1;                                }

  close($input);

   $prmfile = "$prmdir/xex660ftp.prm";
   unless (open $input, "$prmfile") {
           $message = ("Error subr init: can't open ftp login info: $!");
           return -1;               }
   print "       " . "subr init: good open ftp info" . "    " . `date`;

  ## get first line in parm file -> ftp login info
  $line = <$input>;
  ($ftp_site, $ftp_user, $ftp_password, $ftp_path) = split(" ", $line);

  if (!$ftp_site || !$ftp_user || !$ftp_password || !$ftp_path) {
      $message = ("Error subr init: ftp info is incorrect or corrupt");
      close($input);
      return -1;                                                 }
  close($input);
  print "       " . "subr init: ftp info=site,user,password,path-> " . $ftp_site . ", "  . $ftp_user . ", " . $ftp_password . ", " .  $ftp_path;

  return 0;
}

sub init_message {
  my $input = 'fh01';

  # open file containing list of names to email
  $prmfile = "$prmdir/xex660mail.prm";
  unless (open $input,"$prmfile") {
          $message = ("Error subr init_message: unable to open mailing list: $!");
          return -1;              }
    print "       " . "subr init_message: good open mailing list" . "    " . `date`;
  
  ## get all email names/addresses listed into an array
  @names = <$input>;
  if (!$names[0]) {
      $message = ("Error subr init_message: unable to read mailing list");
      close($input);
      return -1;  }
  else { print "       " . "subr init_message: mail to: " . "$names[0]"; }
  close($input);

  return 0;
}

sub extract_files 
{
  # Connect to target instance
  
  print "       " . "subr extract files: " . "    " . `date`;

 	
  my $dbh = DBI->connect("$database", "$username", "$m_password",
         	 {AutoCommit =>0, RaiseError=>1, PrintError=>1});
  if (!$dbh) {
      $message = ("Error subr extract_files: unable to connect to database $database, $username; $DBI::errstr");
      return -1; }
	
  print "       " . "subr extract files: good database connect" . "    " . `date`;
	
  $err_code = 0;

## set up Perl DBI interface to capture the dbms_output from the ORA PLSQL function.        
  $dbh->func(1000000, 'dbms_output_enable');
  
## send as a bind variable the Oracle directory object shared/global env. variable

  my $sql_source = qq(
        	BEGIN
 	               :err_code := pkg_crcom_extract.sf_mitchell_extract(:pathout);
		END;
 	             );

  my $sth = $dbh->prepare($sql_source);
  $sth->bind_param_inout(":err_code", \$err_code, 6);
  $sth->bind_param_inout(":pathout", \$obj_tmpdir, 20);
  $sth->execute();
  $sth->finish;
	
  print "       " .  "subr extract_files: get the function's dbms_output buffer" . "\n";
  while (my $line = $dbh->func( 'dbms_output_get' )) { print "$line\n"; }
	
  $dbh->disconnect();
  
  if ($err_code == -1)  { 
      $message = ("Error subr extract_files: sf_mitchell_extract failed");
      return -1;        }
 	
  print "       " . "subr extract_files completed  "  . `date`;
 	
  return 0;
}

# login to ftp site using $login and $password
# change to directory identified in $ftp_path
# set binary transfer mode

sub sftp_connect {

  $sftp = Net::SFTP::Foreign->new($ftp_site, user=>$ftp_user, password=>$ftp_password);
  if ($sftp->error) {
          $err_code = -1;
          my_exit("*** ERROR connecting to $ftp_site\n $@",$err_code);
                     }

  # Change directory if specified 
  if ( $ftp_path ne "DefaultDir" ) {
     #print "\n Changing to [ $ftp_path ]\n";
     $sftp->setcwd("$ftp_path");
	 #print "\n CurrentWorkingDirectory [", $sftp->cwd, " ]\n";
     if ($sftp->error) {
          $err_code = -1;
          my_exit("Cannot change working directory ", $err_code);
                        }
   }

 print "       " . "subr sftp_connect: good connect, cd directory and set binary mode" . "    " . `date`;

  return $sftp; 
}

### send email notification that extracted zip file is available

sub send_message($$) 
{
  my ($message, $error) = @_;
  my $subject = "Mitchell Update";

  print "       subr send message: " . $message . " " . $error . " " . `date`;

  if (@names == 0) 
   { @names = 'RaceBatch@mitchell.com'; }
   
  foreach $name (@names) 
      {
  	if ($error eq "" || ($name =~ m/mitchell.com/)) 
          { %mail = ( To      => $name,
                From    => 'MitchellUpdate@mitchell.com',
                Subject => $subject,
                Message => $message
              );
        sendmail(%mail);
           }
      }
}

## my_exit used for abend err conditions  
##    include abend exit - e.g. exit -1 or use $err_code or return codes for exit codes

sub my_exit($$) 
{ my ($message,$error) = @_;
      print "       ABEND: " . $message . " " . $error . " " . `date`;
      exit $error ;
}

exit;