# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs

if [ -x /bin/ksh ]; then
export SHELL=/bin/ksh
exec "$SHELL" -l
fi
