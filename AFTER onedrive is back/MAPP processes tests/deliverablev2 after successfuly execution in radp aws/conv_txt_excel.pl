#!/usr/bin/perl -w

use strict;
use warnings;
 
use Excel::Writer::XLSX;

 
my $SourceFile    = $ARGV[0];
my $FileName = $ARGV[1];
my $NumSheets = $ARGV[2];
my $TempDir = $ARGV[3];

my $workbook = Excel::Writer::XLSX->new($FileName);
$workbook->set_optimization();
$workbook->set_tempdir($TempDir);

my $worksheet1;
my $worksheet2;
my $worksheet3;
my $worksheet4;
my $worksheet5;
my $worksheet6;
my $worksheet7;
my $worksheet8;
my $worksheet9;
my $worksheet10;
my $headcol0='REC CNT';
my $headcol1='PART NUMBER';
my $headcol2='OEM';
my $headcol3='ALTPART NUMBER';
my $headcol4='DESCRIPTION';
my $headcol5='PRICE';
my $headcol6='CAPA';
my $headcol7='NFS';
my $headcol8='REM';
my $headcol9='OEM';
my $headcol10='ERROR/WARNING';
my $headcol11='MITCHELL FILE NAME';

if ($NumSheets > 10) {
   print "Too many sheets to be created $NumSheets\n";
   exit 1; 
}

# Add a worksheet
if ($NumSheets == 1) {
   $worksheet1 = $workbook->add_worksheet('Alternate Parts - Exceptions 1');
} 

if ($NumSheets == 2){
	 $worksheet1 = $workbook->add_worksheet('Alternate Parts - Exceptions 1');
	 $worksheet2 = $workbook->add_worksheet('Alternate Parts - Exceptions 2');
	 $worksheet2->write_string(0, 0, $headcol0);
     $worksheet2->write_string(0, 1, $headcol1);
     $worksheet2->write_string(0, 2, $headcol2);
     $worksheet2->write_string(0, 3, $headcol3);
     $worksheet2->write_string(0, 4, $headcol4);
     $worksheet2->write_string(0, 5, $headcol5);
     $worksheet2->write_string(0, 6, $headcol6);
     $worksheet2->write_string(0, 7, $headcol7);
     $worksheet2->write_string(0, 8, $headcol8);
     $worksheet2->write_string(0, 9, $headcol9);
     $worksheet2->write_string(0, 10, $headcol10);
     $worksheet2->write_string(0, 11, $headcol11);
} 

if ($NumSheets == 3){
     $worksheet1 = $workbook->add_worksheet('Alternate Parts - Exceptions 1');
	 $worksheet2 = $workbook->add_worksheet('Alternate Parts - Exceptions 2');
	 $worksheet2->write_string(0, 0, $headcol0);
     $worksheet2->write_string(0, 1, $headcol1);
     $worksheet2->write_string(0, 2, $headcol2);
     $worksheet2->write_string(0, 3, $headcol3);
     $worksheet2->write_string(0, 4, $headcol4);
     $worksheet2->write_string(0, 5, $headcol5);
     $worksheet2->write_string(0, 6, $headcol6);
     $worksheet2->write_string(0, 7, $headcol7);
     $worksheet2->write_string(0, 8, $headcol8);
     $worksheet2->write_string(0, 9, $headcol9);
     $worksheet2->write_string(0, 10, $headcol10);
     $worksheet2->write_string(0, 11, $headcol11);
     $worksheet3 = $workbook->add_worksheet('Alternate Parts - Exceptions 3');
     $worksheet3->write_string(0, 0, $headcol0);
     $worksheet3->write_string(0, 1, $headcol1);
     $worksheet3->write_string(0, 2, $headcol2);
     $worksheet3->write_string(0, 3, $headcol3);
     $worksheet3->write_string(0, 4, $headcol4);
     $worksheet3->write_string(0, 5, $headcol5);
     $worksheet3->write_string(0, 6, $headcol6);
     $worksheet3->write_string(0, 7, $headcol7);
     $worksheet3->write_string(0, 8, $headcol8);
     $worksheet3->write_string(0, 9, $headcol9);
     $worksheet3->write_string(0, 10, $headcol10);
     $worksheet3->write_string(0, 11, $headcol11);
}
     
if ($NumSheets == 4){
     $worksheet1 = $workbook->add_worksheet('Alternate Parts - Exceptions 1');
	 $worksheet2 = $workbook->add_worksheet('Alternate Parts - Exceptions 2');
	  $worksheet2->write_string(0, 0, $headcol0);
     $worksheet2->write_string(0, 1, $headcol1);
     $worksheet2->write_string(0, 2, $headcol2);
     $worksheet2->write_string(0, 3, $headcol3);
     $worksheet2->write_string(0, 4, $headcol4);
     $worksheet2->write_string(0, 5, $headcol5);
     $worksheet2->write_string(0, 6, $headcol6);
     $worksheet2->write_string(0, 7, $headcol7);
     $worksheet2->write_string(0, 8, $headcol8);
     $worksheet2->write_string(0, 9, $headcol9);
     $worksheet2->write_string(0, 10, $headcol10);
     $worksheet2->write_string(0, 11, $headcol11);    
     $worksheet3 = $workbook->add_worksheet('Alternate Parts - Exceptions 3');
     $worksheet3->write_string(0, 0, $headcol0);
     $worksheet3->write_string(0, 1, $headcol1);
     $worksheet3->write_string(0, 2, $headcol2);
     $worksheet3->write_string(0, 3, $headcol3);
     $worksheet3->write_string(0, 4, $headcol4);
     $worksheet3->write_string(0, 5, $headcol5);
     $worksheet3->write_string(0, 6, $headcol6);
     $worksheet3->write_string(0, 7, $headcol7);
     $worksheet3->write_string(0, 8, $headcol8);
     $worksheet3->write_string(0, 9, $headcol9);
     $worksheet3->write_string(0, 10, $headcol10);
     $worksheet3->write_string(0, 11, $headcol11);
     $worksheet4 = $workbook->add_worksheet('Alternate Parts - Exceptions 4');
     $worksheet4->write_string(0, 0, $headcol0);
     $worksheet4->write_string(0, 1, $headcol1);
     $worksheet4->write_string(0, 2, $headcol2);
     $worksheet4->write_string(0, 3, $headcol3);
     $worksheet4->write_string(0, 4, $headcol4);
     $worksheet4->write_string(0, 5, $headcol5);
     $worksheet4->write_string(0, 6, $headcol6);
     $worksheet4->write_string(0, 7, $headcol7);
     $worksheet4->write_string(0, 8, $headcol8);
     $worksheet4->write_string(0, 9, $headcol9);
     $worksheet4->write_string(0, 10, $headcol10);
     $worksheet4->write_string(0, 11, $headcol11);
}

if ($NumSheets == 5){
     $worksheet1 = $workbook->add_worksheet('Alternate Parts - Exceptions 1');
	 $worksheet2 = $workbook->add_worksheet('Alternate Parts - Exceptions 2');
	  $worksheet2->write_string(0, 0, $headcol0);
     $worksheet2->write_string(0, 1, $headcol1);
     $worksheet2->write_string(0, 2, $headcol2);
     $worksheet2->write_string(0, 3, $headcol3);
     $worksheet2->write_string(0, 4, $headcol4);
     $worksheet2->write_string(0, 5, $headcol5);
     $worksheet2->write_string(0, 6, $headcol6);
     $worksheet2->write_string(0, 7, $headcol7);
     $worksheet2->write_string(0, 8, $headcol8);
     $worksheet2->write_string(0, 9, $headcol9);
     $worksheet2->write_string(0, 10, $headcol10);
     $worksheet2->write_string(0, 11, $headcol11);    
     $worksheet3 = $workbook->add_worksheet('Alternate Parts - Exceptions 3');
     $worksheet3->write_string(0, 0, $headcol0);
     $worksheet3->write_string(0, 1, $headcol1);
     $worksheet3->write_string(0, 2, $headcol2);
     $worksheet3->write_string(0, 3, $headcol3);
     $worksheet3->write_string(0, 4, $headcol4);
     $worksheet3->write_string(0, 5, $headcol5);
     $worksheet3->write_string(0, 6, $headcol6);
     $worksheet3->write_string(0, 7, $headcol7);
     $worksheet3->write_string(0, 8, $headcol8);
     $worksheet3->write_string(0, 9, $headcol9);
     $worksheet3->write_string(0, 10, $headcol10);
     $worksheet3->write_string(0, 11, $headcol11);
     $worksheet4 = $workbook->add_worksheet('Alternate Parts - Exceptions 4');
     $worksheet4->write_string(0, 0, $headcol0);
     $worksheet4->write_string(0, 1, $headcol1);
     $worksheet4->write_string(0, 2, $headcol2);
     $worksheet4->write_string(0, 3, $headcol3);
     $worksheet4->write_string(0, 4, $headcol4);
     $worksheet4->write_string(0, 5, $headcol5);
     $worksheet4->write_string(0, 6, $headcol6);
     $worksheet4->write_string(0, 7, $headcol7);
     $worksheet4->write_string(0, 8, $headcol8);
     $worksheet4->write_string(0, 9, $headcol9);
     $worksheet4->write_string(0, 10, $headcol10);
     $worksheet4->write_string(0, 11, $headcol11);
     $worksheet5 = $workbook->add_worksheet('Alternate Parts - Exceptions 5');
     $worksheet5->write_string(0, 0, $headcol0);
     $worksheet5->write_string(0, 1, $headcol1);
     $worksheet5->write_string(0, 2, $headcol2);
     $worksheet5->write_string(0, 3, $headcol3);
     $worksheet5->write_string(0, 4, $headcol4);
     $worksheet5->write_string(0, 5, $headcol5);
     $worksheet5->write_string(0, 6, $headcol6);
     $worksheet5->write_string(0, 7, $headcol7);
     $worksheet5->write_string(0, 8, $headcol8);
     $worksheet5->write_string(0, 9, $headcol9);
     $worksheet5->write_string(0, 10, $headcol10);
     $worksheet5->write_string(0, 11, $headcol11);     
}

if ($NumSheets == 6){
     $worksheet1 = $workbook->add_worksheet('Alternate Parts - Exceptions 1');
	 $worksheet2 = $workbook->add_worksheet('Alternate Parts - Exceptions 2');
	  $worksheet2->write_string(0, 0, $headcol0);
     $worksheet2->write_string(0, 1, $headcol1);
     $worksheet2->write_string(0, 2, $headcol2);
     $worksheet2->write_string(0, 3, $headcol3);
     $worksheet2->write_string(0, 4, $headcol4);
     $worksheet2->write_string(0, 5, $headcol5);
     $worksheet2->write_string(0, 6, $headcol6);
     $worksheet2->write_string(0, 7, $headcol7);
     $worksheet2->write_string(0, 8, $headcol8);
     $worksheet2->write_string(0, 9, $headcol9);
     $worksheet2->write_string(0, 10, $headcol10);
     $worksheet2->write_string(0, 11, $headcol11);    
     $worksheet3 = $workbook->add_worksheet('Alternate Parts - Exceptions 3');
     $worksheet3->write_string(0, 0, $headcol0);
     $worksheet3->write_string(0, 1, $headcol1);
     $worksheet3->write_string(0, 2, $headcol2);
     $worksheet3->write_string(0, 3, $headcol3);
     $worksheet3->write_string(0, 4, $headcol4);
     $worksheet3->write_string(0, 5, $headcol5);
     $worksheet3->write_string(0, 6, $headcol6);
     $worksheet3->write_string(0, 7, $headcol7);
     $worksheet3->write_string(0, 8, $headcol8);
     $worksheet3->write_string(0, 9, $headcol9);
     $worksheet3->write_string(0, 10, $headcol10);
     $worksheet3->write_string(0, 11, $headcol11);
     $worksheet4 = $workbook->add_worksheet('Alternate Parts - Exceptions 4');
     $worksheet4->write_string(0, 0, $headcol0);
     $worksheet4->write_string(0, 1, $headcol1);
     $worksheet4->write_string(0, 2, $headcol2);
     $worksheet4->write_string(0, 3, $headcol3);
     $worksheet4->write_string(0, 4, $headcol4);
     $worksheet4->write_string(0, 5, $headcol5);
     $worksheet4->write_string(0, 6, $headcol6);
     $worksheet4->write_string(0, 7, $headcol7);
     $worksheet4->write_string(0, 8, $headcol8);
     $worksheet4->write_string(0, 9, $headcol9);
     $worksheet4->write_string(0, 10, $headcol10);
     $worksheet4->write_string(0, 11, $headcol11);
     $worksheet5 = $workbook->add_worksheet('Alternate Parts - Exceptions 5');
     $worksheet5->write_string(0, 0, $headcol0);
     $worksheet5->write_string(0, 1, $headcol1);
     $worksheet5->write_string(0, 2, $headcol2);
     $worksheet5->write_string(0, 3, $headcol3);
     $worksheet5->write_string(0, 4, $headcol4);
     $worksheet5->write_string(0, 5, $headcol5);
     $worksheet5->write_string(0, 6, $headcol6);
     $worksheet5->write_string(0, 7, $headcol7);
     $worksheet5->write_string(0, 8, $headcol8);
     $worksheet5->write_string(0, 9, $headcol9);
     $worksheet5->write_string(0, 10, $headcol10);
     $worksheet5->write_string(0, 11, $headcol11);     
     $worksheet6 = $workbook->add_worksheet('Alternate Parts - Exceptions 6');
     $worksheet6->write_string(0, 0, $headcol0);
     $worksheet6->write_string(0, 1, $headcol1);
     $worksheet6->write_string(0, 2, $headcol2);
     $worksheet6->write_string(0, 3, $headcol3);
     $worksheet6->write_string(0, 4, $headcol4);
     $worksheet6->write_string(0, 5, $headcol5);
     $worksheet6->write_string(0, 6, $headcol6);
     $worksheet6->write_string(0, 7, $headcol7);
     $worksheet6->write_string(0, 8, $headcol8);
     $worksheet6->write_string(0, 9, $headcol9);
     $worksheet6->write_string(0, 10, $headcol10);
     $worksheet6->write_string(0, 11, $headcol11);     
}

if ($NumSheets == 7){
     $worksheet1 = $workbook->add_worksheet('Alternate Parts - Exceptions 1');
	 $worksheet2 = $workbook->add_worksheet('Alternate Parts - Exceptions 2');
	  $worksheet2->write_string(0, 0, $headcol0);
     $worksheet2->write_string(0, 1, $headcol1);
     $worksheet2->write_string(0, 2, $headcol2);
     $worksheet2->write_string(0, 3, $headcol3);
     $worksheet2->write_string(0, 4, $headcol4);
     $worksheet2->write_string(0, 5, $headcol5);
     $worksheet2->write_string(0, 6, $headcol6);
     $worksheet2->write_string(0, 7, $headcol7);
     $worksheet2->write_string(0, 8, $headcol8);
     $worksheet2->write_string(0, 9, $headcol9);
     $worksheet2->write_string(0, 10, $headcol10);
     $worksheet2->write_string(0, 11, $headcol11);    
     $worksheet3 = $workbook->add_worksheet('Alternate Parts - Exceptions 3');
     $worksheet3->write_string(0, 0, $headcol0);
     $worksheet3->write_string(0, 1, $headcol1);
     $worksheet3->write_string(0, 2, $headcol2);
     $worksheet3->write_string(0, 3, $headcol3);
     $worksheet3->write_string(0, 4, $headcol4);
     $worksheet3->write_string(0, 5, $headcol5);
     $worksheet3->write_string(0, 6, $headcol6);
     $worksheet3->write_string(0, 7, $headcol7);
     $worksheet3->write_string(0, 8, $headcol8);
     $worksheet3->write_string(0, 9, $headcol9);
     $worksheet3->write_string(0, 10, $headcol10);
     $worksheet3->write_string(0, 11, $headcol11);
     $worksheet4 = $workbook->add_worksheet('Alternate Parts - Exceptions 4');
     $worksheet4->write_string(0, 0, $headcol0);
     $worksheet4->write_string(0, 1, $headcol1);
     $worksheet4->write_string(0, 2, $headcol2);
     $worksheet4->write_string(0, 3, $headcol3);
     $worksheet4->write_string(0, 4, $headcol4);
     $worksheet4->write_string(0, 5, $headcol5);
     $worksheet4->write_string(0, 6, $headcol6);
     $worksheet4->write_string(0, 7, $headcol7);
     $worksheet4->write_string(0, 8, $headcol8);
     $worksheet4->write_string(0, 9, $headcol9);
     $worksheet4->write_string(0, 10, $headcol10);
     $worksheet4->write_string(0, 11, $headcol11);
     $worksheet5 = $workbook->add_worksheet('Alternate Parts - Exceptions 5');
     $worksheet5->write_string(0, 0, $headcol0);
     $worksheet5->write_string(0, 1, $headcol1);
     $worksheet5->write_string(0, 2, $headcol2);
     $worksheet5->write_string(0, 3, $headcol3);
     $worksheet5->write_string(0, 4, $headcol4);
     $worksheet5->write_string(0, 5, $headcol5);
     $worksheet5->write_string(0, 6, $headcol6);
     $worksheet5->write_string(0, 7, $headcol7);
     $worksheet5->write_string(0, 8, $headcol8);
     $worksheet5->write_string(0, 9, $headcol9);
     $worksheet5->write_string(0, 10, $headcol10);
     $worksheet5->write_string(0, 11, $headcol11);     
     $worksheet6 = $workbook->add_worksheet('Alternate Parts - Exceptions 6');
     $worksheet6->write_string(0, 0, $headcol0);
     $worksheet6->write_string(0, 1, $headcol1);
     $worksheet6->write_string(0, 2, $headcol2);
     $worksheet6->write_string(0, 3, $headcol3);
     $worksheet6->write_string(0, 4, $headcol4);
     $worksheet6->write_string(0, 5, $headcol5);
     $worksheet6->write_string(0, 6, $headcol6);
     $worksheet6->write_string(0, 7, $headcol7);
     $worksheet6->write_string(0, 8, $headcol8);
     $worksheet6->write_string(0, 9, $headcol9);
     $worksheet6->write_string(0, 10, $headcol10);
     $worksheet6->write_string(0, 11, $headcol11);     
     $worksheet7 = $workbook->add_worksheet('Alternate Parts - Exceptions 7');
     $worksheet7->write_string(0, 0, $headcol0);
     $worksheet7->write_string(0, 1, $headcol1);
     $worksheet7->write_string(0, 2, $headcol2);
     $worksheet7->write_string(0, 3, $headcol3);
     $worksheet7->write_string(0, 4, $headcol4);
     $worksheet7->write_string(0, 5, $headcol5);
     $worksheet7->write_string(0, 6, $headcol6);
     $worksheet7->write_string(0, 7, $headcol7);
     $worksheet7->write_string(0, 8, $headcol8);
     $worksheet7->write_string(0, 9, $headcol9);
     $worksheet7->write_string(0, 10, $headcol10);
     $worksheet7->write_string(0, 11, $headcol11);     
}

if ($NumSheets == 8){
     $worksheet1 = $workbook->add_worksheet('Alternate Parts - Exceptions 1');
	 $worksheet2 = $workbook->add_worksheet('Alternate Parts - Exceptions 2');
	  $worksheet2->write_string(0, 0, $headcol0);
     $worksheet2->write_string(0, 1, $headcol1);
     $worksheet2->write_string(0, 2, $headcol2);
     $worksheet2->write_string(0, 3, $headcol3);
     $worksheet2->write_string(0, 4, $headcol4);
     $worksheet2->write_string(0, 5, $headcol5);
     $worksheet2->write_string(0, 6, $headcol6);
     $worksheet2->write_string(0, 7, $headcol7);
     $worksheet2->write_string(0, 8, $headcol8);
     $worksheet2->write_string(0, 9, $headcol9);
     $worksheet2->write_string(0, 10, $headcol10);
     $worksheet2->write_string(0, 11, $headcol11);    
     $worksheet3 = $workbook->add_worksheet('Alternate Parts - Exceptions 3');
     $worksheet3->write_string(0, 0, $headcol0);
     $worksheet3->write_string(0, 1, $headcol1);
     $worksheet3->write_string(0, 2, $headcol2);
     $worksheet3->write_string(0, 3, $headcol3);
     $worksheet3->write_string(0, 4, $headcol4);
     $worksheet3->write_string(0, 5, $headcol5);
     $worksheet3->write_string(0, 6, $headcol6);
     $worksheet3->write_string(0, 7, $headcol7);
     $worksheet3->write_string(0, 8, $headcol8);
     $worksheet3->write_string(0, 9, $headcol9);
     $worksheet3->write_string(0, 10, $headcol10);
     $worksheet3->write_string(0, 11, $headcol11);
     $worksheet4 = $workbook->add_worksheet('Alternate Parts - Exceptions 4');
     $worksheet4->write_string(0, 0, $headcol0);
     $worksheet4->write_string(0, 1, $headcol1);
     $worksheet4->write_string(0, 2, $headcol2);
     $worksheet4->write_string(0, 3, $headcol3);
     $worksheet4->write_string(0, 4, $headcol4);
     $worksheet4->write_string(0, 5, $headcol5);
     $worksheet4->write_string(0, 6, $headcol6);
     $worksheet4->write_string(0, 7, $headcol7);
     $worksheet4->write_string(0, 8, $headcol8);
     $worksheet4->write_string(0, 9, $headcol9);
     $worksheet4->write_string(0, 10, $headcol10);
     $worksheet4->write_string(0, 11, $headcol11);
     $worksheet5 = $workbook->add_worksheet('Alternate Parts - Exceptions 5');
     $worksheet5->write_string(0, 0, $headcol0);
     $worksheet5->write_string(0, 1, $headcol1);
     $worksheet5->write_string(0, 2, $headcol2);
     $worksheet5->write_string(0, 3, $headcol3);
     $worksheet5->write_string(0, 4, $headcol4);
     $worksheet5->write_string(0, 5, $headcol5);
     $worksheet5->write_string(0, 6, $headcol6);
     $worksheet5->write_string(0, 7, $headcol7);
     $worksheet5->write_string(0, 8, $headcol8);
     $worksheet5->write_string(0, 9, $headcol9);
     $worksheet5->write_string(0, 10, $headcol10);
     $worksheet5->write_string(0, 11, $headcol11);     
     $worksheet6 = $workbook->add_worksheet('Alternate Parts - Exceptions 6');
     $worksheet6->write_string(0, 0, $headcol0);
     $worksheet6->write_string(0, 1, $headcol1);
     $worksheet6->write_string(0, 2, $headcol2);
     $worksheet6->write_string(0, 3, $headcol3);
     $worksheet6->write_string(0, 4, $headcol4);
     $worksheet6->write_string(0, 5, $headcol5);
     $worksheet6->write_string(0, 6, $headcol6);
     $worksheet6->write_string(0, 7, $headcol7);
     $worksheet6->write_string(0, 8, $headcol8);
     $worksheet6->write_string(0, 9, $headcol9);
     $worksheet6->write_string(0, 10, $headcol10);
     $worksheet6->write_string(0, 11, $headcol11);     
     $worksheet7 = $workbook->add_worksheet('Alternate Parts - Exceptions 7');
     $worksheet7->write_string(0, 0, $headcol0);
     $worksheet7->write_string(0, 1, $headcol1);
     $worksheet7->write_string(0, 2, $headcol2);
     $worksheet7->write_string(0, 3, $headcol3);
     $worksheet7->write_string(0, 4, $headcol4);
     $worksheet7->write_string(0, 5, $headcol5);
     $worksheet7->write_string(0, 6, $headcol6);
     $worksheet7->write_string(0, 7, $headcol7);
     $worksheet7->write_string(0, 8, $headcol8);
     $worksheet7->write_string(0, 9, $headcol9);
     $worksheet7->write_string(0, 10, $headcol10);
     $worksheet7->write_string(0, 11, $headcol11);
     $worksheet8 = $workbook->add_worksheet('Alternate Parts - Exceptions 8');
     $worksheet8->write_string(0, 0, $headcol0);
     $worksheet8->write_string(0, 1, $headcol1);
     $worksheet8->write_string(0, 2, $headcol2);
     $worksheet8->write_string(0, 3, $headcol3);
     $worksheet8->write_string(0, 4, $headcol4);
     $worksheet8->write_string(0, 5, $headcol5);
     $worksheet8->write_string(0, 6, $headcol6);
     $worksheet8->write_string(0, 7, $headcol7);
     $worksheet8->write_string(0, 8, $headcol8);
     $worksheet8->write_string(0, 9, $headcol9);
     $worksheet8->write_string(0, 10, $headcol10);
     $worksheet8->write_string(0, 11, $headcol11);     
}

if ($NumSheets == 9){
     $worksheet1 = $workbook->add_worksheet('Alternate Parts - Exceptions 1');
	 $worksheet2 = $workbook->add_worksheet('Alternate Parts - Exceptions 2');
	  $worksheet2->write_string(0, 0, $headcol0);
     $worksheet2->write_string(0, 1, $headcol1);
     $worksheet2->write_string(0, 2, $headcol2);
     $worksheet2->write_string(0, 3, $headcol3);
     $worksheet2->write_string(0, 4, $headcol4);
     $worksheet2->write_string(0, 5, $headcol5);
     $worksheet2->write_string(0, 6, $headcol6);
     $worksheet2->write_string(0, 7, $headcol7);
     $worksheet2->write_string(0, 8, $headcol8);
     $worksheet2->write_string(0, 9, $headcol9);
     $worksheet2->write_string(0, 10, $headcol10);
     $worksheet2->write_string(0, 11, $headcol11);    
     $worksheet3 = $workbook->add_worksheet('Alternate Parts - Exceptions 3');
     $worksheet3->write_string(0, 0, $headcol0);
     $worksheet3->write_string(0, 1, $headcol1);
     $worksheet3->write_string(0, 2, $headcol2);
     $worksheet3->write_string(0, 3, $headcol3);
     $worksheet3->write_string(0, 4, $headcol4);
     $worksheet3->write_string(0, 5, $headcol5);
     $worksheet3->write_string(0, 6, $headcol6);
     $worksheet3->write_string(0, 7, $headcol7);
     $worksheet3->write_string(0, 8, $headcol8);
     $worksheet3->write_string(0, 9, $headcol9);
     $worksheet3->write_string(0, 10, $headcol10);
     $worksheet3->write_string(0, 11, $headcol11);
     $worksheet4 = $workbook->add_worksheet('Alternate Parts - Exceptions 4');
     $worksheet4->write_string(0, 0, $headcol0);
     $worksheet4->write_string(0, 1, $headcol1);
     $worksheet4->write_string(0, 2, $headcol2);
     $worksheet4->write_string(0, 3, $headcol3);
     $worksheet4->write_string(0, 4, $headcol4);
     $worksheet4->write_string(0, 5, $headcol5);
     $worksheet4->write_string(0, 6, $headcol6);
     $worksheet4->write_string(0, 7, $headcol7);
     $worksheet4->write_string(0, 8, $headcol8);
     $worksheet4->write_string(0, 9, $headcol9);
     $worksheet4->write_string(0, 10, $headcol10);
     $worksheet4->write_string(0, 11, $headcol11);
     $worksheet5 = $workbook->add_worksheet('Alternate Parts - Exceptions 5');
     $worksheet5->write_string(0, 0, $headcol0);
     $worksheet5->write_string(0, 1, $headcol1);
     $worksheet5->write_string(0, 2, $headcol2);
     $worksheet5->write_string(0, 3, $headcol3);
     $worksheet5->write_string(0, 4, $headcol4);
     $worksheet5->write_string(0, 5, $headcol5);
     $worksheet5->write_string(0, 6, $headcol6);
     $worksheet5->write_string(0, 7, $headcol7);
     $worksheet5->write_string(0, 8, $headcol8);
     $worksheet5->write_string(0, 9, $headcol9);
     $worksheet5->write_string(0, 10, $headcol10);
     $worksheet5->write_string(0, 11, $headcol11);     
     $worksheet6 = $workbook->add_worksheet('Alternate Parts - Exceptions 6');
     $worksheet6->write_string(0, 0, $headcol0);
     $worksheet6->write_string(0, 1, $headcol1);
     $worksheet6->write_string(0, 2, $headcol2);
     $worksheet6->write_string(0, 3, $headcol3);
     $worksheet6->write_string(0, 4, $headcol4);
     $worksheet6->write_string(0, 5, $headcol5);
     $worksheet6->write_string(0, 6, $headcol6);
     $worksheet6->write_string(0, 7, $headcol7);
     $worksheet6->write_string(0, 8, $headcol8);
     $worksheet6->write_string(0, 9, $headcol9);
     $worksheet6->write_string(0, 10, $headcol10);
     $worksheet6->write_string(0, 11, $headcol11);     
     $worksheet7 = $workbook->add_worksheet('Alternate Parts - Exceptions 7');
     $worksheet7->write_string(0, 0, $headcol0);
     $worksheet7->write_string(0, 1, $headcol1);
     $worksheet7->write_string(0, 2, $headcol2);
     $worksheet7->write_string(0, 3, $headcol3);
     $worksheet7->write_string(0, 4, $headcol4);
     $worksheet7->write_string(0, 5, $headcol5);
     $worksheet7->write_string(0, 6, $headcol6);
     $worksheet7->write_string(0, 7, $headcol7);
     $worksheet7->write_string(0, 8, $headcol8);
     $worksheet7->write_string(0, 9, $headcol9);
     $worksheet7->write_string(0, 10, $headcol10);
     $worksheet7->write_string(0, 11, $headcol11); 
     $worksheet8 = $workbook->add_worksheet('Alternate Parts - Exceptions 8');
     $worksheet8->write_string(0, 0, $headcol0);
     $worksheet8->write_string(0, 1, $headcol1);
     $worksheet8->write_string(0, 2, $headcol2);
     $worksheet8->write_string(0, 3, $headcol3);
     $worksheet8->write_string(0, 4, $headcol4);
     $worksheet8->write_string(0, 5, $headcol5);
     $worksheet8->write_string(0, 6, $headcol6);
     $worksheet8->write_string(0, 7, $headcol7);
     $worksheet8->write_string(0, 8, $headcol8);
     $worksheet8->write_string(0, 9, $headcol9);
     $worksheet8->write_string(0, 10, $headcol10);
     $worksheet8->write_string(0, 11, $headcol11);  
     $worksheet9 = $workbook->add_worksheet('Alternate Parts - Exceptions 9');
     $worksheet9->write_string(0, 0, $headcol0);
     $worksheet9->write_string(0, 1, $headcol1);
     $worksheet9->write_string(0, 2, $headcol2);
     $worksheet9->write_string(0, 3, $headcol3);
     $worksheet9->write_string(0, 4, $headcol4);
     $worksheet9->write_string(0, 5, $headcol5);
     $worksheet9->write_string(0, 6, $headcol6);
     $worksheet9->write_string(0, 7, $headcol7);
     $worksheet9->write_string(0, 8, $headcol8);
     $worksheet9->write_string(0, 9, $headcol9);
     $worksheet9->write_string(0, 10, $headcol10);
     $worksheet9->write_string(0, 11, $headcol11);    
}

if ($NumSheets == 10){
     $worksheet1 = $workbook->add_worksheet('Alternate Parts - Exceptions 1');
	 $worksheet2 = $workbook->add_worksheet('Alternate Parts - Exceptions 2');
	  $worksheet2->write_string(0, 0, $headcol0);
     $worksheet2->write_string(0, 1, $headcol1);
     $worksheet2->write_string(0, 2, $headcol2);
     $worksheet2->write_string(0, 3, $headcol3);
     $worksheet2->write_string(0, 4, $headcol4);
     $worksheet2->write_string(0, 5, $headcol5);
     $worksheet2->write_string(0, 6, $headcol6);
     $worksheet2->write_string(0, 7, $headcol7);
     $worksheet2->write_string(0, 8, $headcol8);
     $worksheet2->write_string(0, 9, $headcol9);
     $worksheet2->write_string(0, 10, $headcol10);
     $worksheet2->write_string(0, 11, $headcol11);    
     $worksheet3 = $workbook->add_worksheet('Alternate Parts - Exceptions 3');
     $worksheet3->write_string(0, 0, $headcol0);
     $worksheet3->write_string(0, 1, $headcol1);
     $worksheet3->write_string(0, 2, $headcol2);
     $worksheet3->write_string(0, 3, $headcol3);
     $worksheet3->write_string(0, 4, $headcol4);
     $worksheet3->write_string(0, 5, $headcol5);
     $worksheet3->write_string(0, 6, $headcol6);
     $worksheet3->write_string(0, 7, $headcol7);
     $worksheet3->write_string(0, 8, $headcol8);
     $worksheet3->write_string(0, 9, $headcol9);
     $worksheet3->write_string(0, 10, $headcol10);
     $worksheet3->write_string(0, 11, $headcol11);
     $worksheet4 = $workbook->add_worksheet('Alternate Parts - Exceptions 4');
     $worksheet4->write_string(0, 0, $headcol0);
     $worksheet4->write_string(0, 1, $headcol1);
     $worksheet4->write_string(0, 2, $headcol2);
     $worksheet4->write_string(0, 3, $headcol3);
     $worksheet4->write_string(0, 4, $headcol4);
     $worksheet4->write_string(0, 5, $headcol5);
     $worksheet4->write_string(0, 6, $headcol6);
     $worksheet4->write_string(0, 7, $headcol7);
     $worksheet4->write_string(0, 8, $headcol8);
     $worksheet4->write_string(0, 9, $headcol9);
     $worksheet4->write_string(0, 10, $headcol10);
     $worksheet4->write_string(0, 11, $headcol11);
     $worksheet5 = $workbook->add_worksheet('Alternate Parts - Exceptions 5');
     $worksheet5->write_string(0, 0, $headcol0);
     $worksheet5->write_string(0, 1, $headcol1);
     $worksheet5->write_string(0, 2, $headcol2);
     $worksheet5->write_string(0, 3, $headcol3);
     $worksheet5->write_string(0, 4, $headcol4);
     $worksheet5->write_string(0, 5, $headcol5);
     $worksheet5->write_string(0, 6, $headcol6);
     $worksheet5->write_string(0, 7, $headcol7);
     $worksheet5->write_string(0, 8, $headcol8);
     $worksheet5->write_string(0, 9, $headcol9);
     $worksheet5->write_string(0, 10, $headcol10);
     $worksheet5->write_string(0, 11, $headcol11);     
     $worksheet6 = $workbook->add_worksheet('Alternate Parts - Exceptions 6');
     $worksheet6->write_string(0, 0, $headcol0);
     $worksheet6->write_string(0, 1, $headcol1);
     $worksheet6->write_string(0, 2, $headcol2);
     $worksheet6->write_string(0, 3, $headcol3);
     $worksheet6->write_string(0, 4, $headcol4);
     $worksheet6->write_string(0, 5, $headcol5);
     $worksheet6->write_string(0, 6, $headcol6);
     $worksheet6->write_string(0, 7, $headcol7);
     $worksheet6->write_string(0, 8, $headcol8);
     $worksheet6->write_string(0, 9, $headcol9);
     $worksheet6->write_string(0, 10, $headcol10);
     $worksheet6->write_string(0, 11, $headcol11);     
     $worksheet7 = $workbook->add_worksheet('Alternate Parts - Exceptions 7');
     $worksheet7->write_string(0, 0, $headcol0);
     $worksheet7->write_string(0, 1, $headcol1);
     $worksheet7->write_string(0, 2, $headcol2);
     $worksheet7->write_string(0, 3, $headcol3);
     $worksheet7->write_string(0, 4, $headcol4);
     $worksheet7->write_string(0, 5, $headcol5);
     $worksheet7->write_string(0, 6, $headcol6);
     $worksheet7->write_string(0, 7, $headcol7);
     $worksheet7->write_string(0, 8, $headcol8);
     $worksheet7->write_string(0, 9, $headcol9);
     $worksheet7->write_string(0, 10, $headcol10);
     $worksheet7->write_string(0, 11, $headcol11); 
     $worksheet8 = $workbook->add_worksheet('Alternate Parts - Exceptions 8');
     $worksheet8->write_string(0, 0, $headcol0);
     $worksheet8->write_string(0, 1, $headcol1);
     $worksheet8->write_string(0, 2, $headcol2);
     $worksheet8->write_string(0, 3, $headcol3);
     $worksheet8->write_string(0, 4, $headcol4);
     $worksheet8->write_string(0, 5, $headcol5);
     $worksheet8->write_string(0, 6, $headcol6);
     $worksheet8->write_string(0, 7, $headcol7);
     $worksheet8->write_string(0, 8, $headcol8);
     $worksheet8->write_string(0, 9, $headcol9);
     $worksheet8->write_string(0, 10, $headcol10);
     $worksheet8->write_string(0, 11, $headcol11);  
     $worksheet9 = $workbook->add_worksheet('Alternate Parts - Exceptions 9');
     $worksheet9->write_string(0, 0, $headcol0);
     $worksheet9->write_string(0, 1, $headcol1);
     $worksheet9->write_string(0, 2, $headcol2);
     $worksheet9->write_string(0, 3, $headcol3);
     $worksheet9->write_string(0, 4, $headcol4);
     $worksheet9->write_string(0, 5, $headcol5);
     $worksheet9->write_string(0, 6, $headcol6);
     $worksheet9->write_string(0, 7, $headcol7);
     $worksheet9->write_string(0, 8, $headcol8);
     $worksheet9->write_string(0, 9, $headcol9);
     $worksheet9->write_string(0, 10, $headcol10);
     $worksheet9->write_string(0, 11, $headcol11);   
     $worksheet10 = $workbook->add_worksheet('Alternate Parts - Exceptions 9');
     $worksheet10->write_string(0, 0, $headcol0);
     $worksheet10->write_string(0, 1, $headcol1);
     $worksheet10->write_string(0, 2, $headcol2);
     $worksheet10->write_string(0, 3, $headcol3);
     $worksheet10->write_string(0, 4, $headcol4);
     $worksheet10->write_string(0, 5, $headcol5);
     $worksheet10->write_string(0, 6, $headcol6);
     $worksheet10->write_string(0, 7, $headcol7);
     $worksheet10->write_string(0, 8, $headcol8);
     $worksheet10->write_string(0, 9, $headcol9);
     $worksheet10->write_string(0, 10, $headcol10);
     $worksheet10->write_string(0, 11, $headcol11);   
}

open INPUT, $SourceFile or die "Cannot open file: $!\n";

my ($x,$y) = (0,0);
my ($a) = (1); #start at 1 since header is written above for worksheet2
my ($b) = (1); #start at 1 since header is written above for worksheet3
my ($c) = (1); #start at 1 since header is written above for worksheet4
my ($d) = (1); #start at 1 since header is written above for worksheet5
my ($e) = (1); #start at 1 since header is written above for worksheet6
my ($f) = (1); #start at 1 since header is written above for worksheet7
my ($g) = (1); #start at 1 since header is written above for worksheet8
my ($h) = (1); #start at 1 since header is written above for worksheet9
my ($i) = (1); #start at 1 since header is written above for worksheet10

while (<INPUT>){ 
 chomp;
 my @list = split /\~/,$_;
 foreach my $cell (@list){
 if ($x <= 1000000){
 	  $worksheet1->write_string($x, $y++, $cell);
 	}elsif (($x > 1000000) && ($x <= 2000000)){
 	  $worksheet2->write_string($a, $y++, $cell);
 	  #print "a = $a\n";
 	}elsif (($x > 2000000) && ($x <= 3000000)){
 	  $worksheet3->write_string($b, $y++, $cell);
    }elsif (($x > 3000000) && ($x <= 4000000)){
 	  $worksheet4->write_string($c, $y++, $cell);
    }elsif (($x > 4000000) && ($x <= 5000000)){
 	  $worksheet5->write_string($d, $y++, $cell); 	  
    }elsif (($x > 5000000) && ($x <= 6000000)){
 	  $worksheet6->write_string($e, $y++, $cell); 	  
 	}elsif (($x > 6000000) && ($x <= 7000000)){
 	  $worksheet7->write_string($f, $y++, $cell); 	  
 	}elsif (($x > 7000000) && ($x <= 8000000)){
 	  $worksheet8->write_string($g, $y++, $cell); 	  
 	}elsif (($x > 8000000) && ($x <= 9000000)){
 	  $worksheet9->write_string($h, $y++, $cell); 	  
 	}elsif (($x > 9000000) && ($x <= 10000000)){
 	  $worksheet10->write_string($i, $y++, $cell); 	  
 	}elsif (($x >= 10000001)){
 	  exit 1;
 	}
 }
 
  $x++;$y=0;
 
 if (($x > 1000001) && ($x <= 2000001)){
 	 $a++;
 }
 
 if (($x > 2000001) && ($x <= 3000001)){
  	 $b++;
 }
 
 if (($x > 3000001) && ($x <= 4000001)){
  	 $c++;
 }
 
 if (($x > 4000001) && ($x <= 5000001)){
  	 $d++;
 }
 
  if (($x > 5000001) && ($x <= 6000001)){
  	 $e++;
 }
 
  if (($x > 6000001) && ($x <= 7000001)){
  	 $f++;
 }
  
  if (($x > 7000001) && ($x <= 8000001)){
  	 $g++;
 } 
 
  if (($x > 8000001) && ($x <= 9000001)){
  	 $h++;
 }
  
  if (($x > 9000001) && ($x <= 10000001)){
  	 $i++;
 }
}
close($FileName);

$workbook->close();

