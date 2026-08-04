#$Id: ttt_fixlen.awk,v 1.2 2014/09/17 23:58:50 pg2697 Exp $
#############################################################################
# This awk file is used to test checkin/checkout/prodmove.
#
# 12    <== change this in order for checkin to detect a change.
#############################################################################
{
  if( /[A-Z,a-z,0-9]/ )
  {
    LINE=$0
    while(length(LINE) < LEN + 1)
      LINE=LINE " "
    print substr(LINE,1,LEN)
  }
}
