#$Id: setgdg.awk,v 1.2 2006/09/06 00:06:30 jw97143 Exp $
BEGIN  { FS="(" }
{

#set dataset name
  ds=$1

#set relative generation number
  gn=substr($2,1,match($2,")") - 1)

#build list file of all dataset entries
  lne = "ls -1 "ds".g?? | sort -r -o" Tfile
  system( lne );

  FS="."
  getline < Tfile

#set $0 to selected '(-?)' dataset name
  while( int(gn) < 0 )
  {
    if( getline tmp < Tfile )
      $0 = tmp
    gn = gn + 1
  }
  close( Tfile )

#set dataset generation number
  if( $0 > "" )
    no=substr($NF,2,4)
  else
    no="0"
  
#set 'NEW' dataset generation number
  if( match( toupper(DISP), "NEW" ) > 0 )
    nw = int(no) + int(gn)
  else
    nw = int(no)

#print full dataset name
  printf( "%s.g%2.2d\n", ds, nw > 0 ? nw:1 )

#remove temp file
  system( "rm " Tfile )
}
