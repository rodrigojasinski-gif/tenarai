#!/usr/bin/perl
# Error codes:

use Net::FTP;
use Getopt::Std;

getopts('f:l:u:h:p:r:');

my $remote_host   = $opt_h;
my $remote_user   = $opt_u;
my $remote_pass   = $opt_p;
my $remote_dir    = $opt_r;
my $local_dir     = $opt_l;
my $file_name     = $opt_f;

#Verify that local directory exists
if ( ! -d $local_dir){
   exit 1;
}

#Verify that local file exists
if ( ! -r $local_dir."/".$file_name){
   exit 1;
}

#Main

$ftp = Net::FTP->new($remote_host, Debug => 9);
exit 1 if not defined $ftp;
exit 1 if not ($ftp->login($remote_user,$remote_pass));
if ($ftp->cwd($remote_dir)){
    $ftp->put($local_dir."/".$file_name);
    $ftp->quit;
}
else {
     exit 1;
}

exit 0;
