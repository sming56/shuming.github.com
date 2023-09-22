#!/usr/bin/env  bash

set_cgfs_iops_bps_for_container()
{
        pid=`docker inspect -f {{.State.Pid}} $1`
        sys_raid=`docker inspect -f {{.GraphDriver.Data.DeviceName}} $1`
        data_raid=`docker inspect -f "{{range .Mounts}}{{.Source}},{{end}}" $1 | awk -F"," '{for(i=1;i<NF;i++) print $i}' | grep lvm`

        echo "pid = $pid"
	cgrouppath=`cat /proc/$pid/cgroup | grep pids | awk -F ":" '{print $3}'`

        wiopspath="/sys/fs/cgroup/blkio$cgrouppath/blkio.throttle.write_iops_device"
        riopspath="/sys/fs/cgroup/blkio$cgrouppath/blkio.throttle.read_iops_device"
        wbpspath="/sys/fs/cgroup/blkio$cgrouppath/blkio.throttle.write_bps_device"
        rbpspath="/sys/fs/cgroup/blkio$cgrouppath/blkio.throttle.read_bps_device"


        sys_id=`dmsetup ls | grep $sys_raid | awk '{print $2}'| sed 's/(//g' | sed 's/)//g'`
        echo "sys_id = $sys_id"

        data_str=`mount | grep $data_raid | awk '{print $1}' | awk -F"/" '{print $4}'`
        data_id=`dmsetup ls | grep $data_str | awk '{print $2}'| sed 's/(//g' | sed 's/)//g'`
        echo "data_id = $data_id"

        sys_iops="$sys_id 0"
        data_iops="$data_id 100000"
        sys_bps="$sys_id 0"
        data_bps="$data_id 1073741824"

        # set
        echo $sys_iops > $wiopspath
        echo $data_iops >> $wiopspath
        echo $sys_iops > $riopspath
        echo $data_iops >> $riopspath
        echo $sys_bps > $wbpspath
        echo $data_bps >> $wbpspath
        echo $sys_bps > $rbpspath
        echo $data_bps >> $rbpspath

        #after set
        wiops_p=`cat $wiopspath`
        riops_p=`cat $riopspath`
        wbps_p=`cat $wbpspath`
        rbps_p=`cat $rbpspath`

        echo "wiops_p = $wiops_p"
        echo "riops_p = $riops_p"
        echo "wbps_p = $wbps_p"
        echo "rbps_p = $rbps_p"

}


#for all app container
id=`docker ps | grep -v pause | grep -v CONTAINER | awk '{print $1}'`

#ARR=($id)
#for ELEM in "${ARR[@]}"
#do
#        echo $ELEM
#  $1=container id
set_cgfs_iops_bps_for_container $1
#done
