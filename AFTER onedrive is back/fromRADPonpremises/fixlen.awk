#$Id: fixlen.awk,v 1.2 2006/09/06 00:19:42 jw97143 Exp $
{
  if( /[A-Z,a-z,0-9]/ )
  {
    LINE=$0
    while(length(LINE) < LEN + 1)
      LINE=LINE " "
    print substr(LINE,1,LEN)
  }
}
