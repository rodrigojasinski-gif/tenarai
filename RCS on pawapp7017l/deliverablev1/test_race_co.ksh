#! /bin/ksh
# test_race_co.ksh
# rj132422 - exercise race_co through the REAL ssh -> sudo -> SUDO_USER chain on the
#            dev box, using a throwaway RCS archive. No prod / service account needed.

#----- config (override via env if needed) ---------------------------------
DEVHOST=${DEVHOST:-dawapp7017l}        # dev host to ssh into (the box itself)
RACE_CO=${RACE_CO:-$HOME/race_co}      # path to the wrapper under test
RCSBIN=${RCSBIN:-/usr/local/bin}       # where co/ci/rlog live on dev
SUDO_AS=${SUDO_AS:-}                    # e.g. "-u some-acct"; empty = sudo to root
#---------------------------------------------------------------------------

WORK=/tmp/race_test.$$
EXPECT=${LOGNAME%%@*}                   # expected lock owner = your login minus @domain

echo "Testing wrapper : $RACE_CO"
echo "Via             : ssh $DEVHOST  sudo $SUDO_AS ... (real SUDO_USER)"
echo "Expected locker : $EXPECT"
echo

# 1) throwaway RCS archive, bootstrapped with a clean name so ci accepts it
  mkdir -p $WORK || exit 1
  cd $WORK || exit 1
  echo "race_co test $(date)" > tfile.ksh
  LOGNAME=$EXPECT $RCSBIN/ci -q -i -t-test -m"init" tfile.ksh
  if [ $? != 0 ]; then echo "SETUP FAILED (ci -i)"; cd /; rm -rf $WORK; exit 1; fi

# 2) lock it through the real chain: ssh into dev -> sudo -> race_co
  echo ">>> locking via real ssh+sudo ..."
  ssh -t $DEVHOST "cd $WORK && sudo $SUDO_AS $RACE_CO -l tfile.ksh"

# 3) verify who holds the lock
  echo
  echo "--- lock section of tfile.ksh,v ---"
  $RCSBIN/rlog -h tfile.ksh | sed -n '/^locks/,/^comment/p'
  echo

  if $RCSBIN/rlog -h tfile.ksh | grep -q "[[:space:]]${EXPECT}:[0-9]"; then
    echo "PASS - lock owner is '$EXPECT' (clean name, no @)"
  else
    echo "FAIL - expected lock owner '$EXPECT' not found (see lock section above)"
  fi

# 4) cleanup
  cd /; rm -rf $WORK
