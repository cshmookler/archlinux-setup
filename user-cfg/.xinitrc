TIMEOUT=300
xset s TIMEOUT TIMEOUT dpms TIMEOUT TIMEOUT TIMEOUT
nohup xss-lock slock </dev/null >/dev/null 2>&1 &
slstatus &
dwm
physlock -p "This console is locked by $USER"
