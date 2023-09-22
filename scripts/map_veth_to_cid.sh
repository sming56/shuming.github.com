#!/usr/bin/bash
#cmd <veth device name>

vethn=$1
num=`ip addr | grep $vethn |  awk -F ':' '{print $1}'`
ids=`docker ps |grep -v pause | grep -v "prometheus-node" | awk '{print $1}'`
for id in $ids; do
    if [[ $id == "CONTAINER" ]]; then
#        echo "skiping $id"
        continue
    fi
    ifnum=`docker exec -it $id ip addr | grep eth0@ | awk -F ':' '{print $2}' | sed 's/eth0@if\([0-9]*\).*/\1/g'`
    if [ $ifnum == $num ]; then
       echo "veth: $vethn belongs to $id"
       exit
    fi
done

