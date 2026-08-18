#!/usr/local/bin/perl -w

#******************************************************************************#
# GetFtpFile.pl 
#
#   Retrieves a file from the ftp server indicated in the parm file
#
#   Three Input Parameters
#         1) ftp account file
#               - space delimited file containing
#                       - user id
#                       - password
#                       - server name
#                       - target directory (or DefaultDir)
#                       - file type (binary or ascii)
#         2) filename to be retrieved  (remote filename)
#         3) output file name and path (local filename)
#
#******************************************************************************#

use strict;
use Net::FTP;
#--use Net::SMTP;

my $NumArgs    = 3;
my $PrmFile    = $ARGV[0];
my $FileToPull = $ARGV[1];
my $OutputFile = $ARGV[2];

my $Usage = "Usage: $0 [ ftpAcctFile fileToPull outputFile ]\n\n";
my $ftp;
my @pull_file;
my $file_exists;
my $Date;

#-- main program starts here --#

# Verify script was called w/ correct # args
    if ( @ARGV ne $NumArgs ) {
       print "\n\n*** ERROR Invalid Arguments Passed ***\n"; 
       print $Usage;
       exit 1;
    }

# Log in to ftp server
    FtpLogin();

# Check if file exists
    CheckAndGetFtpFile();

    exit 0;

#-- main program ends here --#


#-- subprocesses follow --#

sub CalculateDate {

       $Date = `date +%Y/%m/%d" "%H:%M:%S`;
       chomp $Date;
}


sub FtpLogin {

       CalculateDate;
       print "\n$Date - Connecting to FTP server";

       #* Retrieve 1) user id
       #*          2) password
       #*          3) ftp server name
       #*          4) remote directory (DefaultDir if no change required)
       #*          5) file type (defaults to binary) from parm file
       open(FH,"$PrmFile");
       my ($User,$Pass,$FtpServer,$RemoteDir,$FileType) = split /\s+/, <FH>;
       close(FH);

       #* Log in to ftp server
       $ftp = Net::FTP->new($FtpServer,Debug=>0,Passive=>0);
       ##$ftp = Net::FTP->new($FtpServer,Debug=>-1);

       $ftp->login("$User", "$Pass")
          or die "*** ERROR connecting to $FtpServer\n", $ftp->message;

       #* Change directory if specified 
       if ( $RemoteDir ne "DefaultDir" ) {
         print "\n$Date - Changing to $RemoteDir";
         $ftp->cwd("$RemoteDir")
            or die "Cannot change working directory ", $ftp->message;
       }

       #* Default to binary (unless ascii specified)
       if ( $FileType eq "ascii" ) {
         print "\n$Date - Changing to ascii";
         $ftp->ascii;
       }
       else {
         print "\n$Date - Changing to binary";
         $ftp->binary;
       }

}

sub CheckAndGetFtpFile {

       CalculateDate;

       print "\n$Date - Checking if file $FileToPull exists";
       @pull_file = $ftp->ls("$FileToPull");

       if ( defined $pull_file[0] ) {
         GetFtpFile();
       }
       else {
         print "\n$Date - File $FileToPull doesn't exist on FTP server";
       }
}

sub GetFtpFile {

       my $FileSizeCurr;
       my $FileSizeNow;
       my @LocalFileSize;

       CalculateDate;

       # remote file exists; is it ready to be pulled?
       print "\n$Date - File $pull_file[0] found - waiting to confirm file transfer is complete";

       # try at least 10 mins before giving up
       for ( my $i=0; $i<=10; $i++ ) {
           #################################################################################################
           # Get current file size on the FTP site
           # Note: The following "size" statements do NOT work on all of the FTP sites, 
           #       therefore, FileSizeCurr and FileSizeNow will be compromised.
           #       Then when these variables are used in this statement: if ( $FileSizeCurr eq $FileSizeNow )
           #       this message will be returned: "Use of uninitialized value in string ... "
           $FileSizeCurr = $ftp->size("$pull_file[0]");
           sleep 60; 
           $FileSizeNow = $ftp->size("$pull_file[0]");
           # Waited one minute... Now determine if the source file size has changed.
           # If the file size has NOT changed, start the transfer... otherwise try again!
           if ( $FileSizeCurr eq $FileSizeNow ) {
              
              CalculateDate;
              print "\n$Date - Retrieving $pull_file[0] - output to $OutputFile";
              print "\n       Remote file size $FileSizeNow";

              # file xfer complete; pull file
              $ftp->get("$pull_file[0]","$OutputFile")
                 or die "*** ERROR retrieving $pull_file[0]\n", $ftp->message;

              CalculateDate;
              print "\n$Date - File Transfer Complete";

              @LocalFileSize = (split /\s+/,`ls -l $OutputFile`);
              print "\n       Local file size: $LocalFileSize[4]";

              print "\n\n*NOTE: File sizes may differ depending on how the remote and";
              print " local servers define EndOfLine\n\n";

              last;
           }
           else {
              CalculateDate;
              print "\n$Date - File sizes NOT equal - waiting...";
           }
           
           if ( $i == 10 ) {
              CalculateDate;
              print "\n$Date - File Not Transferred."; 
           }
       }

  $ftp->quit;
  CalculateDate;
  print "\n$Date - Disconnected from FTP server\n";
}
