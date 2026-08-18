#!/usr/bin/perl -w

#******************************************************************************#
# GetSftpFile.pl 
#
#   Retrieves a file from the sftp server indicated in the parm file
#
#   Three Input Parameters
#         1) sftp account file
#               - space delimited file containing
#                       - user id
#                       - password
#                       - server name
#                       - target directory (or DefaultDir)
#                       - file type (binary or ascii)
#                       - port (optional)
#         2) filename to be retrieved  (remote filename)
#         3) output file name and path (local filename)
#
#******************************************************************************#

use strict;
use Net::SFTP::Foreign;
use Net::SMTP;

my $NumArgs    = 3;
my $PrmFile    = $ARGV[0];
my $FileToPull = $ARGV[1];
my $OutputFile = $ARGV[2];

my $Usage = "Usage: $0 [ ftpAcctFile fileToPull outputFile ]\n\n";
my $sftp;
my $pull_file;
my $Date;

#-- main program starts here --#

# Verify script was called w/ correct # args
    if ( @ARGV ne $NumArgs ) {
       print "\n\nGetSftpFile.pl *** ERROR Invalid Arguments Passed ***\n"; 
       print $Usage;
       exit 1;
    }

# Log in to ftp server
    print "\n\nGetSftpFile.pl (Main) - Executing SftpLogin using:";
    print "\n\nGetSftpFile.pl (Main) - PrmFile: $PrmFile";
    SftpLogin();
    print "\n\nGetSftpFile.pl (Main) - Return from Execute of SftpLogin - $Date";

# Check if file exists and get it
    print "\n\nGetSftpFile.pl (Main) - Executing CheckAndGetSftpFile - $Date - using:";
    print "\n\nGetSftpFile.pl (Main) - FileToPull:  $FileToPull";
    print "\n\nGetSftpFile.pl (Main) - OutputFile: $OutputFile";
    CheckAndGetSftpFile();
    print "\n\nGetSftpFile.pl (Main) - Return from Execute of CheckAndGetSftpFile - $Date";


    exit 0;

#-- main program ends here --##################################################################################################


#-- subprocesses follow    --##################################################################################################

sub CalculateDate {

       $Date = `date +%Y/%m/%d" "%H:%M:%S`;
       chomp $Date;
}


sub SftpLogin {


       CalculateDate;

       print "\n\nGetSftpFile.pl (SftpLogin sub) - Connecting to SFTP server - $Date";

       #* Retrieve 1) user id
       #*          2) password
       #*          3) sftp server name
       #*          4) remote directory (DefaultDir if no change required)
       #*          5) file type (defaults to binary) from parm file
       #*          6) port
       open(FH,"$PrmFile");
       my ($User,$Pass,$SftpServer,$RemoteDir,$FileType,$Port) = split /\s+/, <FH>;
       close(FH);

       #* If prm file doesn't contain port (at end of record), default it to 22		
	   if (not $Port)
        {
         $Port=22;
        }


  #***Uncomment for testing in debug*** $Net::SFTP::Foreign::debug = -1;
  
  #***print "\nGetSftpFile.pl (SftpLogin sub) - $User - $Pass - $SftpServer - $RemoteDir - $FileType - $Port \n";

       #* Log in to ftp server

       print "\n\nGetSftpFile.pl (SftpLogin sub) - Connecting to SFTP server - $Date";

       $sftp = Net::SFTP::Foreign->new($SftpServer, user=>$User, port=>$Port, password=>$Pass)
          or die "GetSftpFile.pl (SftpLogin sub) - *** ERROR connecting to $SftpServer\n", $sftp->message;

       #* Change directory if specified 
       if ( $RemoteDir ne "DefaultDir" ) {
         print "\nGetSftpFile.pl (SftpLogin sub) - Changing to [ $RemoteDir ]";
         $sftp->setcwd("$RemoteDir")
            or die "Cannot change working directory ", $sftp->message;
       }
}

sub CheckAndGetSftpFile {

       CalculateDate;

       print "\nGetSftpFile.pl (CheckAndGetSftpFile sub) - Checking if file $FileToPull exists  - $Date";     

       $pull_file = $sftp->ls( wanted => qr/$FileToPull/);
       if ( defined @$pull_file[0] )
         {
             $FileToPull=@$pull_file[0] -> {filename}; 
             print "\n\nGetSftpFile.pl (CheckAndGetSftpFile sub) - Executing GetSftpFile using FileToPull: $FileToPull";
 
             GetSftpFile();

             print "\n\nGetSftpFile.pl (CheckAndGetSftpFile sub) - Return from Execute of GetSftpFile"; 

         }
      else 
         {
             print "\nGetSftpFile.pl (CheckAndGetSftpFile sub) - File $FileToPull doesn't exist on FTP server";
         }
         

}

sub GetSftpFile {

       my $FileSizeCurr;
       my $FileSizeNow;
       my @LocalFileSize;
      
       CalculateDate;
       
       # remote file exists; is it ready to be pulled?
       print "\nGetSftpFile.pl (GetSftpFile sub) - File $FileToPull found - waiting to confirm file transfer is complete - $Date";

       # try at least 10 mins before giving up
       for ( my $i=0; $i<=10; $i++ ) {
           #################################################################################################
           # Get current file size on the SFTP site
           # Note: The following "size" statements do NOT work on all of the SFTP sites; therefore,  
           #       FileSizeCurr and FileSizeNow will be compromised.
           #       Then when these variables are used in this statement: if ( $FileSizeCurr eq $FileSizeNow )
           #       this message will be returned: "Use of uninitialized value in string ... "
           #       So changed command used to get sizes.
           #################################################################################################
           $pull_file = $sftp->ls( wanted => qr/$FileToPull/);
           $FileSizeCurr = @$pull_file[0]-> {a}-> {size}; 
           ########$FileSizeCurr = $sftp->size("$FileToPull");
           sleep 60; 
          
           # Waited one minutes... Now determine if the source file size has changed.
           # If the file size has NOT changed, start the transfer... otherwise try again!
           
           $pull_file = $sftp->ls( wanted => qr/$FileToPull/);
           $FileSizeNow = @$pull_file[0]-> {a}-> {size};            
           if ( $FileSizeCurr eq $FileSizeNow ) {
              
              CalculateDate;
              print "\nGetSftpFile.pl (GetSftpFile sub) - Retrieving $FileToPull  - $Date";
              print "\nGetSftpFile.pl (GetSftpFile sub) - Output to $OutputFile";
              print "\nGetSftpFile.pl (GetSftpFile sub) - Remote file size $FileSizeNow";

              # file xfer complete; pull file
              $sftp->get("$FileToPull","$OutputFile")
                 or die "*** ERROR retrieving $FileToPull\n", $sftp->message;

              CalculateDate;
              print "\nGetSftpFile.pl (GetSftpFile sub) - File Transfer Complete  - $Date";

              @LocalFileSize = (split /\s+/,`ls -l $OutputFile`);
              print "\nGetSftpFile.pl (GetSftpFile sub) - Local file size: $LocalFileSize[4]";

              print "\n\nGetSftpFile.pl (GetSftpFile sub) - *NOTE: File sizes may differ depending on how the remote and";
              print " local servers define EndOfLine\n\n";

              last;
           }
           else {
              CalculateDate;
              print "\nGetSftpFile.pl (GetSftpFile sub) - File sizes NOT equal - waiting...  - $Date";
           }
           
           if ( $i == 10 ) {
              CalculateDate;
              print "\nGetSftpFile.pl (GetSftpFile sub) - File Not Transferred.   - $Date"; 
           }
       }

  CalculateDate;
  print "\nGetSftpFile.pl (GetSftpFile sub) - Preparing to disconnect.   - $Date";
  $sftp->disconnect;

  CalculateDate;
  print "\nGetSftpFile.pl (GetSftpFile sub) - Disconnected from SFTP server  - $Date\n";
}
