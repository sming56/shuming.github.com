#!/bin/bash

# simply check if host is in smartnic mode
ifconfig ovs0 1>/dev/null 2>&1
if [ $? -ne 0 ]; then
    # echo "Not smartnic, exiting"
    exit 0
fi

# Only mnic2.0 support to set max-revalidator
mnic=`rpm -q mlnx-ofa_kernel-5.2-OFED*`
if [ $? -ne 0 ]; then
	exit 0
fi

cfg=`ovs-vsctl get Open_vSwitch . other_config | grep max-revalidator`
max_num=`echo $cfg | awk -F "=" '{print $3}' | awk -F "}" '{print $1}'`
if [[ $max_num == \"10000\" ]]
then
	echo `hostname` "set to 10000 already"
else
	ovs-vsctl set Open_vSwitch . other_config:max-revalidator=10000
	echo `hostname` "fix to 10000 done"
fi
