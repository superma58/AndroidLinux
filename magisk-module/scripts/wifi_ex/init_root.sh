
ETH_MAC="00:00:00:00:13:8f"
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
        unshare --mount --net -p setsid /data/adb/pivot_root_demo /mnt/ubuntu  /bin/bash -c "/bin/bash /bin/init_env.sh >> /tmp/init_log" >> /sdcard/log 2>&1 < /dev/null
    fi

    interfaces=$(ip link | grep BROADCAST | awk -F: '{print $2}')
    for iface in $interfaces; do
        mac_address=$(ip link show $iface | grep ether | awk '{print $2}')
        echo "Checking interface: $iface with MAC: $mac_address"
        if [ "$mac_address" == "$ETH_MAC" ]; then
            echo "MAC address matches! Move $iface to linux env."
            sshd_id=$(ps -ef | grep ssh[d] | awk '{print $2}')
            echo "$(date)" 'sshd pid:', $sshd_id

            if [ -n "$sshd_id" ]; then
                echo "$(date) start to move $iface to $sshd_id"
                ip link set dev $iface netns $sshd_id
            fi
        fi
    done
    sleep 5
done
