#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Prompts
PS0=''
PS1='\[\e[0m\]$(EXIT_CODE="$?"; [ "$EXIT_CODE" -eq "0" ] || echo "\[\e[31;1m\]$EXIT_CODE\[\e[0m\]:")\[\e[32;1m\]\u@\h\[\e[0m\]:\[\e[94;1m\]\w\[\e[0m\]$ '
PS2='> '

# Aliases
alias l='ls --color=auto -alF'
alias ls='ls --color=auto -A'
alias sl='ls --color=auto -A'
alias grep='grep --color=auto'
