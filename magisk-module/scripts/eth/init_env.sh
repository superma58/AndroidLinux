#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin
export HOME=/root
export LANG=C.UTF-8

mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devpts devpts /dev/pts
mount -t selinuxfs selinuxfs /sys/fs/selinux

mkdir -p /data
mount /dev/block/sdc46 /data
mount --bind /data/adb/nma/root/ /root
/tmp/cgroupfs-mount || echo ok


ROUTER_IP="192.168.1.1"
LOCAL_IP="192.168.1.110/24" # you should add a static IP rule in your router.
ETH_MAC="6c:1f:f7:15:4d:1a"


while true; do
    interfaces=$(ip link | grep BROADCAST | awk -F: '{print $2}')
    for iface in $interfaces; do
        mac_address=$(ip link show $iface | grep ether | awk '{print $2}')
        echo "Checking interface: $iface with MAC: $mac_address"
        if [ "$mac_address" == "$ETH_MAC" ]; then
            echo "MAC address matches! "
            if ip addr show $iface | grep -q "state DOWN"; then
                echo "Interface $iface is down, enable it."
                ip link set $iface up
                if [ $? -eq 0 ]; then
                    echo "Succeed to enable $iface"
                else
                    echo "Fail to enable $iface"
                fi
            fi
            if ip addr show $iface | grep "inet" | grep -q "192.168"; then
                echo "Interface $iface has been assigned ipv4"
                if ps -ef | grep ssh[d]; then
                    echo "$(date)" sshd is running
                else
                    sshd
                    echo "$(date)" start sshd
                fi
            else
                echo "Interface $iface has no ipv4."
                ip addr add $LOCAL_IP dev $iface
                ip route add default via $ROUTER_IP dev $iface || echo
                ip link set lo up
            fi
            ip addr show $iface

            echo -e "\nChecking the ipv6."
            $SCRIPT_DIR/static_ipv6.sh
        fi
    done

    sleep 10
done
