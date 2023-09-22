#!/bin/bash

host=`hostname`

function close_xps() {
    for queue in `ls -1 /sys/class/net/$1/queues/ | grep tx`
    do
        value=`cat /sys/class/net/$1/queues/${queue}/xps_cpus`
        echo "$1 ${queue} $value" >> xps-${host}.log
        echo 0 > /sys/class/net/$1/queues/${queue}/xps_cpus
    done
}

rpm -q mnic-init > /dev/null
if [ $? -ne 0 ]; then
    echo "not mnic machine"
    exit 0
fi

cat /proc/net/dev | grep ovs0 > /dev/null
if [ $? -ne 0 ]; then
    echo "not mnic machine"
    exit 0
fi

for port in `ls -1 /sys/class/net/`
do
    if [ ! -f /sys/class/net/$port/phys_port_name ]; then
        continue
    fi
    if [ ! -d /sys/class/net/$port/device/physfn ]; then
        continue
    fi
    echo "close xps => $port"
    close_xps $port
done
