xmodmap /etc/vim_keyboard_layout/xmodmap-vim
xset s 120 120 dpms 120 120 120
nohup xss-lock slock </dev/null >/dev/null 2>&1 &
slstatus &
dwm
physlock -p "This console is locked by $USER"
