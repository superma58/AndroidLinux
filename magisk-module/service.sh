#!/system/bin/sh

sleep 30

setsid sh scripts/eth/init_root.sh >> /sdcard/log 2>&1 < /dev/null

