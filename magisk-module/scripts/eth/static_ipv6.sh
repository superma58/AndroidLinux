#!/bin/bash

# Check if it has a ipv6.
# If got a ipv6, try to set a static unchanged ipv6.
# Set a AAAA DNS record with this static ipv6.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

Domain="jojomom.fun"
RR="nc"

# iface="eth0"
iface="$1"
ipv6_pre="2409"
info=$(ip add show $iface 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "No found $iface"
    exit 0
fi

# Parse ip info
echo "$info"
static_ips=$(echo "$info" | grep -oP "(?<=inet6 )$ipv6_pre.*(?=/64 scope global +$)")
echo "Static ip is $static_ips"
dynamic_ip=$(echo "$info" | grep -oP "(?<=inet6 )$ipv6_pre.*(?=/64 scope global.+mngtmpaddr.*)" | head -n 1)
echo "Dynamic ip is $dynamic_ip"

# Generate new ipv6
max_retries=5
new_ipv6=""
gen_new_ipv6() {
  ipv6_prefix=$(echo $1 | cut -d':' -f1-4)
  old_prefix=""
  for attempt in $(seq 1 $max_retries); do
    echo "Attempt $attempt..."
    if [ -f /tmp/last_ipv6 ] && [ "$attempt" == "1" ]; then
      # Try to use the old ipv6.
      new_ipv6=$(cat /tmp/last_ipv6)
      old_prefix=$(echo $new_ipv6 | cut -d':' -f1-4)
      if [ "$old_prefix" != "$ipv6_prefix" ]; then
        echo "Old ipv6 has different prefix, $new_ipv6"
        old_prefix=""
      else
        echo "Use old ipv6: $new_ipv6"
      fi
    fi
    if [ "$old_prefix" == "" ]; then
      random_suffix=$(printf "%x:%x:%x:%x" $((RANDOM%65536)) $((RANDOM%65536)) $((RANDOM%65536)) $((RANDOM%65536)))
      new_ipv6="$ipv6_prefix:$random_suffix"
      echo "Generate random ipv6: $new_ipv6"
    fi
    if ping6 -c 2 "$new_ipv6" &>/dev/null; then
        echo "$new_ipv6 exists, renew it."
    else
        echo "$new_ipv6 is unique."
        return 0
    fi

    if [[ $attempt -eq $max_retries ]]; then
        echo "Max retries reached. Exiting with failure."
        return 1
    fi
    # sleep 2
done
}

# loop all static ipv6, remove the ones with different prefix and keep a right one.
if [ "$dynamic_ip" == "" ]; then
    echo "No found dynamic ip, pls check later"
    exit 0
fi
prefix=$(echo $dynamic_ip | cut -d':' -f1-4)
found=""
for ip in $static_ips; do
    static_prefix=$(echo $ip | cut -d':' -f1-4)
    if [ "$prefix" == "$static_prefix" ]; then
        found="$ip"
        continue
    else
        echo "Remove invalid ipv6 $ip from $iface"
        ip addr del $ip/64 dev $iface
    fi
done
if [ "$found" == "" ]; then
    echo "No found a static ipv6 in $iface, will add a new one"
    if gen_new_ipv6 $dynamic_ip; then
        echo "This new ipv6 $new_ipv6 is validated. Add it to $iface."
        ip addr add $new_ipv6/64 dev $iface
        found="$new_ipv6"
        # save the ipv6
        echo "$new_ipv6" > /tmp/last_ipv6
    fi
    echo "Current $iface looks like:"
    ip addr show $iface
fi

$SCRIPT_DIR/ipv6_aliyun_dns.sh $Domain $RR AAAA $found
