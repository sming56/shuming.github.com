#!/usr/bin/bash

containers=$(docker ps | grep -v pause | grep -v node_exporter |wc -l)
if [ $containers == 1 ]
then
    if [ -e /service/com.sankuai.hulknode.kubelet.* ]
    then
        svc -du /service/com.sankuai.hulknode.kubelet*
    else  [ -e /service/com.sankuai.k8s.kubelet* ]
        svc -du /service/com.sankuai.k8s.kubelet*
    fi
    echo "------kubelet on $host restarted-----------"
fi
