#!/system/bin/sh

sleep 30

setsid sh /data/adb/modules/SetUpLinuxEnv/scripts/eth/init_root.sh >> /sdcard/log 2>&1 < /dev/null

