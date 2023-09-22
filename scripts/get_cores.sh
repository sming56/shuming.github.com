#!/usr/bin/bash -x
max_loop=0
host_names=$1
#give your username and password here
pass=$3
user=$2

sshpass -p $pass ssh -t $user@$host_names -o StrictHostKeychecking=no sudo -iu sankuai sudo -s wget -O /tmp/copy_crash.sh http://kernel.sankuai.com/tools/test_scripts/copy_crash.sh
sshpass -p $pass ssh -t $user@$host_names -o StrictHostKeychecking=no sudo -iu sankuai sudo -s chmod a+x /tmp/copy_crash.sh
sshpass -p $pass ssh -t $user@$host_names -o StrictHostKeychecking=no sudo -iu sankuai sudo -s /tmp/copy_crash.sh

rm -rf /opt/cores_saved/bt.output
/opt/cores_saved/get_cores_byscp.sh $host_names $user $pass
core_file=`ls /opt/cores_saved/$host_names/*/vmcore`
crash_time=`echo $core_file | awk -F'/' '{print $5}'`
kernel_version=`uname -a | awk '{print $3}'`
echo host:$host_names kernel_version:$kernel_version crash_date:$crash_time >> /opt/cores_saved/bt.output
if [ ! -z $core_file -a -f $core_file ]; then
    crash $core_file /usr/lib/debug/lib/modules/$kernel_version/vmlinux -i /opt/cores_saved/bt.batch  >> /opt/cores_saved/get_cores.log
else
   echo "There is no crash core in $host_names"
fi

sshpass -p $pass ssh -t $user@$host_names -o StrictHostKeychecking=no sudo -iu sankuai sudo -s rm -rf /tmp/copy_crash.sh
sshpass -p $pass ssh -t $user@$host_names -o StrictHostKeychecking=no sudo -iu sankuai sudo -s rm -rf /tmp/crash_cores
#echo "All hosts installed: $host_names"
