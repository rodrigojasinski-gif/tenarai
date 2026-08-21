# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# rj132422 - troca pra ksh no login interativo
if [ -z "$KSH_VERSION" ] && [ -x /usr/bin/ksh ] && [[ $- == *i* ]]; then
    export SHELL=/usr/bin/ksh
    exec /usr/bin/ksh -l
fi

# User specific environment and startup programs
