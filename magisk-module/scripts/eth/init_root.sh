#!/bin/bash

ETH_MAC="6c:1f:f7:15:4d:1a"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

mkdir /mnt/ubuntu
mount | grep /mnt/ubuntu || mount -o loop /data/adb/ubuntu-24.04-mybuilt.img /mnt/ubuntu

mkdir -p /mnt/ubuntu/bin
cp $SCRIPT_DIR/init_env.sh /mnt/ubuntu/bin/init_env.sh
chmod +x /mnt/ubuntu/bin/init_env.sh

while true; do
    echo "$(date) check the init status"

    if ps -ef | grep pivot_root_dem[o]; then
        echo "init_env.sh is running"
    else
        # Why should we use the tini?
        # Without the tini, the root process (PID 1) in the new namespace of `unshare -p` can't handle some signals.
        # It cause the whole process group terminate.
        # For example, the `apt install **` can cause this issue when it's installing the package.
        #
        # The tini is downloaded from https://github.com/krallin/tini/releases.
        # Choose the static version. Because it runs in the android linuv env, it can't load some standard glibc.
        #
        # unshare --mount --net -p setsid /data/adb/pivot_root_demo /mnt/ubuntu  /bin/bash -c "/bin/bash /bin/init_env.sh >> /tmp/init_log" >> /sdcard/log 2>&1 < /dev/null
        unshare --mount --net -p setsid /data/adb/nma/root/tini -- /data/adb/pivot_root_demo /mnt/ubuntu  /bin/bash -c "/bin/bash /bin/init_env.sh >> /tmp/init_log" >> /sdcard/log 2>&1 < /dev/null
    fi

    interfaces=$(ip link | grep BROADCAST | awk -F: '{print $2}')
    for iface in $interfaces; do
        mac_address=$(ip link show $iface | grep ether | awk '{print $2}')
        echo "Checking interface: $iface with MAC: $mac_address"
        if [ "$mac_address" == "$ETH_MAC" ]; then
            echo "MAC address matches! Move $iface to linux env."
            init_env_pid=$(ps -ef | grep '/bin/init_env.s[h]' | grep -v 'init_log' | awk '{print $2}')
            echo "$(date)" 'init_env.sh pid:', $init_env_pid

            if [ -n "$init_env_pid" ]; then
                echo "$(date) start to move $iface to $init_env_pid"
                ip link set dev $iface netns $init_env_pid
            fi
        fi
    done
    sleep 10
done
