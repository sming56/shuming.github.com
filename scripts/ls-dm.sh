#!/bin/sh


list=`docker ps |grep -v pause |grep -v node-exporter | awk  {'print $1'} | sed -n '1!p'`
for i in $list
do
pid=`docker inspect -f {{.State.Pid}} $i`
cgrouppath=`cat /proc/$pid/cgroup | head -n 1 | awk -F ":" '{print $3}'`
read_bps=`cat /sys/fs/cgroup/blkio$cgrouppath/blkio.throttle.read_bps_device | tr '\n' '   '`
write_bps=`cat /sys/fs/cgroup/blkio$cgrouppath/blkio.throttle.write_bps_device  | tr '\n' '   '`
read_iops=`cat /sys/fs/cgroup/blkio$cgrouppath/blkio.throttle.read_iops_device  | tr '\n' '   '`
write_iops=`cat /sys/fs/cgroup/blkio$cgrouppath/blkio.throttle.write_iops_device  | tr '\n' '   '`
cpuset_cpus=`cat /sys/fs/cgroup/cpuset$cgrouppath/cpuset.cpus`
cpuset_mems=`cat /sys/fs/cgroup/cpuset$cgrouppath/cpuset.mems`
host_name=$(docker exec $i hostname| tr -d '\r')
docker_vg=$(docker inspect $i |grep DeviceName |awk -F "\"" {'print $4'})
system_disk=$(ls -l /dev/mapper/$docker_vg |awk -F '/' {'print $5'})
tmp=$(docker inspect $i |grep "Source" |grep "hulk~lvm"|awk -F '/' {'print $6'})
total_mem=$(docker exec $i free -h | grep "Mem:" |awk {'print $2'})
total_cpu=$(docker exec $i cat /proc/cpuinfo  |grep processor |wc -l)
system_os=$(docker exec $i cat /etc/redhat-release)
if [ "${#tmp}" != "0" ] ; then
num1=$(echo $tmp | cut -f1 -d "-")
num2=$(echo $tmp | cut -f2 -d "-")
num3=$(echo $tmp | cut -f3 -d "-")
num4=$(echo $tmp | cut -f4 -d "-")
num5=$(echo $tmp | cut -f5 -d "-")
volume_vg="$num1--$num2--$num3--$num4--$num5"
data_disk=$(ls -l /dev/mapper/ |grep $volume_vg |awk -F '/' {'print $2'})
fi
echo -e "\033[41;37m -----------------------------------$i-------------------------------------- \033[0m"
printf "hostname    : %-48s\n" $host_name
echo "os          : $system_os"
printf "dm_device   : %-8s %-8s\n" $system_disk $data_disk
echo "cpu         : $total_cpu"
echo "mem         : $total_mem"
echo "read_bps    : $read_bps"
echo "write_bps   : $write_bps"
echo "read_iops   : $read_iops"
echo "write_iops  : $write_iops"
echo "cpuset_cpus : $cpuset_cpus"
echo "cpuset_mems : $cpuset_mems"
done

