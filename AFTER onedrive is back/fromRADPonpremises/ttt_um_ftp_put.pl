#!/usr/local/bin/perl -w
#$Id: ttt_um_ftp_put.pl,v 1.3 2014/09/18 00:00:17 pg2697 Exp $
#############################################################################
#
# Test version of a perl script - used to test checkin/checkout/prodmove
#
# 12       <=====change this so that checkin recognizes a change
#############################################################################

# Error codes:  
# 100   Invalid local path
# 101   Invalid local file
# 102   Invalid hostname
# 103   Invalid username/password
# 104   Invalid remote path
# 105   No zz file found
# 106   File listed in service file but not found

use Net::FTP;
use Getopt::Std;

getopts('f:l:u:h:p:r:');

my $service_file  = $opt_f;
my $remote_host   = $opt_h;
my $local_dir     = $opt_l;
my $remote_user   = $opt_u;
my $remote_pass   = $opt_p;
my $remote_dir    = $opt_r;


#Verify that local directory exists
if ( ! -d $local_dir){
   exit 100;
}

#Verify that service file exists
if ( ! -r $local_dir."/".$service_file){
   exit 101;
}

#Main

$ftp = Net::FTP->new($remote_host, Debug => 0);
exit 103 if not defined $ftp;
exit 104 if not ($ftp->login($remote_user,$remote_pass));
if ($ftp->cwd($remote_dir)){
   ProcessService($service_file,$local_dir);
   $ftp->quit;
}
else {
     exit 104;
}


sub ProcessService {
  my ($service_file,$service_path) = @_;
  $service_path=$service_path."/";
  my $zz_service_list_file = $service_path."zz".$service_file;
  if ( ! -r $zz_service_list_file){
     exit 105;
  }
  open(LIST,$service_path.$service_file);
  while (<LIST>){
      chop;
      if ( ! -r $service_path.$_){
         exit 106;
      }
      $ftp->put($service_path.$_);
  }
  close(LIST);

  $ftp->put($service_path.$service_file);
  $ftp->put($zz_service_list_file);
}
