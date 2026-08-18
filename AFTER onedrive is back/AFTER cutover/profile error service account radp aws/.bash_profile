# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

if [ -x /bin/ksh ] && [ -t 0 ]; then
    # rj132422 - interactive login: switch to a ksh login shell (it reads ~/.profile)
    export SHELL=/bin/ksh
    exec "$SHELL" -l
else
    # rj132422 - non-interactive (ActiveBatch, no TTY): load env from ~/.profile without an
    # interactive shell. No exec = no hang, but PATH / Oracle / RACE env still get set.
    export SHELL=/bin/ksh
    [ -f "$HOME/.profile" ] && . "$HOME/.profile"
fi
