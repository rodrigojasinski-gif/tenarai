# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

if [ -x /bin/ksh ]; then
    export SHELL=/bin/ksh
    exec "$SHELL" -l
fi


