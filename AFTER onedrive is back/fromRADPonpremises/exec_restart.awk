#$Id: exec_restart.awk,v 1.2 2006/09/06 00:22:39 jw97143 Exp $
{
  if( substr($0,1,5) == "#STEP" )           # first '#STEP'
  {
    CONT=1
    while( CONT )
    {
      if( RESTART == $2 )                   # test of RESTART variable
      {
        while( CONT )
        {
          print $0                          # print all remaining lines
          CONT=getline
        }
      }
      else
      {
        CONT=getline                        # bypass line
      }
    }
  }
  else
  {
    print $0                                # prints all until first '#STEP'
  }
}
