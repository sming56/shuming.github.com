#!/bin/bash

log_dir=/opt/meituan/zhaoyufei05

date=`date +%Y-%m-%d`
time=`date +%H:%M:%S` 

# yarn目录
yarn_cpu=`cat /sys/fs/cgroup/cpu/yarn/container*/cgroup.procs`
yarn_mem=`cat /sys/fs/cgroup/memory/yarn/container*/cgroup.procs`

# sshd目录
sshd_mem=`cat /sys/fs/cgroup/memory/system.slice/sshd.service/cgroup.procs`
sshd_cpu=`cat /sys/fs/cgroup/cpu/system.slice/sshd.service/cgroup.procs`
echo $yarn_cpu
echo $yarn_mem
echo $sshd_mem
echo $sshd_cpu
if [ -d $log_dir ]
then 
	if [ -f $log_dir/yarn_mem.$date ]
		then 
			echo $time >> $log_dir/yarn_mem.$date
			for mem in $yarn_mem
			do
				echo $mem >> $log_dir/yarn_mem.$date
				echo "---" >> $log_dir/yarn_mem.$date
				cat /proc/$mem/cmdline >> $log_dir/yarn_mem.$date
				echo "---" >> $log_dir/yarn_mem.$date
			done
		else 
			touch $log_dir/yarn_mem.$date
	fi
	if [ -f $log_dir/sshd_mem.$date ]
		then 
			echo $time >> $log_dir/sshd_mem.$date
			for mem in $sshd_mem
			do
				echo $mem >> $log_dir/sshd_mem.$date
				echo "---" >> $log_dir/sshd_mem.$date
				cat /proc/$mem/cmdline >> $log_dir/sshd_mem.$date
				echo "---" >> $log_dir/sshd_mem.$date
			done
		else
			touch $log_dir/sshd_mem.$date
	fi
	if [ -f $log_dir/yarn_cpu.$date ]
		then 
			echo "*******************Start***********************"
			echo $time >> $log_dir/yarn_cpu.$date
			for cpu in $yarn_cpu
			do
				echo $cpu >> $log_dir/yarn_cpu.$date
				echo "---" >> $log_dir/yarn_cpu.$date
				cat /proc/$cpu/cmdline >> $log_dir/yarn_cpu.$date
				echo "---" >> $log_dir/yarn_cpu.$date
			done
		else
			touch $log_dir/yarn_cpu.$date
	fi
	if [ -f $log_dir/sshd_cpu.$date ]
		then 
			echo "*******************Start***********************"
			echo $time >> $log_dir/sshd_cpu.$date
			for cpu in $sshd_cpu
			do
				echo $cpu >> $log_dir/sshd_cpu.$date
				echo "---" >> $log_dir/sshd_cpu.$date
				cat /proc/$cpu/cmdline >> $log_dir/sshd_cpu.$date
				echo "---" >> $log_dir/sshd_cpu.$date
			done
		else
			touch $log_dir/sshd_cpu.$date
	fi

else
	mkdir -p $log_dir
fi
