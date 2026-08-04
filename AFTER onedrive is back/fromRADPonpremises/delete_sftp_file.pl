#!/usr/local/bin/perl -w

#******************************************************************************#
# DeleteSftpFile.pl 
#
#   Deletes a file from the sftp server indicated in the parm file
#
#   Two Input Parameters
#         1) sftp account file
#               - space delimited file containing
#                       - user id
#                       - password
#                       - server name
#                       - target directory (or DefaultDir)
#                       - file type (binary or ascii)
#                       - port (optional)
#         2) filename to be retrieved  (remote filename)
#
#******************************************************************************#

use strict;
use Net::SFTP::Foreign;
use Net::SMTP;

my $NumArgs    = 2;
my $PrmFile    = $ARGV[0];
my $FileToDelete = $ARGV[1];

my $Usage = "Usage: $0 [ ftpAcctFile fileToDelete ]\n\n";
my $sftp;
my $delete_file;
my $Date;

#-- main program starts here --#

# Verify script was called w/ correct # args
    if ( @ARGV ne $NumArgs ) {
       print "\n\n*** ERROR Invalid Arguments Passed ***\n"; 
       print $Usage;
       exit 1;
    }

# Log in to ftp server
    SftpLogin();

# Check if file exists
    CheckAndDeleteSftpFile();

    exit 0;

#-- main program ends here --#


#-- subprocesses follow --#

sub CalculateDate {

       $Date = `date +%Y/%m/%d" "%H:%M:%S`;
       chomp $Date;
}


sub SftpLogin {

       CalculateDate;
       print "\n$Date - Connecting to SFTP server";

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

       #* Log in to ftp server

  #***Uncomment for testing in debug***   $Net::SFTP::Foreign::debug = -1;

  #*print "\n$User - $Pass - $SftpServer - $RemoteDir - $FileType - $Port \n";

       $sftp = Net::SFTP::Foreign->new($SftpServer, user=>$User, port=>$Port, password=>$Pass)
          or die "*** ERROR connecting to $SftpServer\n", $sftp->message;

       #* Change directory if specified 
       if ( $RemoteDir ne "DefaultDir" ) {
         print "\n$Date - Changing to [ $RemoteDir ] \n";
         $sftp->setcwd("$RemoteDir")
            or die "Cannot change working directory ", $sftp->message;
       }

}

sub CheckAndDeleteSftpFile {

       CalculateDate;

       print "\n$Date - Checking if file $FileToDelete exists \n";
       
       $delete_file = $sftp->ls( wanted => qr/$FileToDelete/);

       
       if ( defined @$delete_file[0] )
         {
             $FileToDelete=@$delete_file[0] -> {filename};  
             DeleteSftpFile();
         }
      else 
         {
             print "\n$Date - File $FileToDelete doesn't exist on SFTP server";
         }
         

}

sub DeleteSftpFile {

       CalculateDate;

       print "\n$Date - Deleting $FileToDelete \n";
        
       $sftp->remove("$FileToDelete")
            or die "*** ERROR deleting $FileToDelete\n", $sftp->message;

       CalculateDate;
       print "\n$Date - File Removal Complete \n";

  $sftp->disconnect;
 
  CalculateDate;

  print "\n$Date - Disconnected from SFTP server\n";

}
