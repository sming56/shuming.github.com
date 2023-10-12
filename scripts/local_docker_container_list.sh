#!/bin/bash

CONTAINER_NAME=""

usage() {
	echo "使用: $(basename "$0") [参数]"
	echo ""
	echo "参数:"
	echo "	-s          [ set-hldy-dataapp-search-query ]"
	echo "	-h          显示帮助信息"
	echo ""
	echo "说明:"
	echo "	不带参数，默认显示所有本地容器的信息"
	echo "	-s 只显示指定容器的信息"
	exit "$1"
}

do_start() {
	IMAGES_INFO=$(docker images)

	c_total_mem=0
	c_total_cpu=0

	flag="0"

	list=$(docker ps | grep -v pause | grep -v node-exporter | awk '{print $1}' | sed -n '1!p')
	for i in $list; do
		host_name=$(cat "$(docker inspect -f '{{.HostsPath}}' $i)" | grep "set-" | awk '{print $2}')
		if [ ! -z "$CONTAINER_NAME" ]; then
			tmp_container_name=$(basename "$host_name" .mt)
			if [ "$CONTAINER_NAME" == "$tmp_container_name" ]; then
				flag="1"
			else
				continue
			fi
		fi

		pid=$(docker inspect -f '{{.State.Pid}}' $i)
		cgrouppath=$(cat /proc/$pid/cgroup | grep "memory:" | awk -F ":" '{print $3}')

		read_bps=$(tr '\n' '   ' </sys/fs/cgroup/blkio${cgrouppath}/blkio.throttle.read_bps_device)
		write_bps=$(tr '\n' '   ' </sys/fs/cgroup/blkio${cgrouppath}/blkio.throttle.write_bps_device)
		read_iops=$(tr '\n' '   ' </sys/fs/cgroup/blkio${cgrouppath}/blkio.throttle.read_iops_device)
		write_iops=$(tr '\n' '   ' </sys/fs/cgroup/blkio${cgrouppath}/blkio.throttle.write_iops_device)

		cpuset_cpus=$(cat /sys/fs/cgroup/cpuset${cgrouppath}/cpuset.cpus)
		cpuset_mems=$(cat /sys/fs/cgroup/cpuset${cgrouppath}/cpuset.mems)
		wmark_ratio=$(cat /sys/fs/cgroup/memory${cgrouppath}/memory.wmark_ratio)
		high_wmark=$(expr "$(cat /sys/fs/cgroup/memory${cgrouppath}/memory.high_wmark_limit_in_bytes)" / 1024 / 1024)
		low_wmark=$(expr "$(cat /sys/fs/cgroup/memory${cgrouppath}/memory.low_wmark_limit_in_bytes)" / 1024 / 1024)
		docker_vg=$(docker inspect -f '{{.GraphDriver.Data.DeviceName}}' $i)
		system_disk=$(readlink -f /dev/mapper/${docker_vg})
		rootfs_path=$(findmnt -n -o TARGET ${system_disk})
		volume_path=$(docker inspect -f '{{json .Mounts}}' $i | jq -r '.[] |select(.Destination == "/docker") | .Source')
		volume_type=$(basename $volume_path)
		data_disk=""
		if [ "$volume_type" == "hulkebs" ]; then
			data_disk=$(findmnt -n -o SOURCE --target ${volume_path})
		else
			volume_vg=$(echo ${volume_path} | awk -F'[/~-]' '{print $6"-"$7"-"$8"-"$9"-"$10}' | sed 's/-/--/g')
			data_disk=$(readlink -f /dev/mapper/volumevg-${volume_vg})
		fi

		system_disk_readahead=$(blockdev --getra $system_disk)
		data_disk_readahead=$(blockdev --getra $data_disk)
		system_disk_maxsect=$(blockdev --getmaxsect $system_disk)
		data_disk_maxsect=$(blockdev --getmaxsect $data_disk)

		created=$(docker inspect --format='{{.Created}}' $i | awk -F'[T.]' '{print $1" "$2}')
		started=$(docker inspect --format='{{.State.StartedAt}}' $i | awk -F'[T.]' '{print $1" "$2}')

		total_mem=$(expr "$(cat /sys/fs/cgroup/memory$cgrouppath/memory.limit_in_bytes)" / 1024 / 1024 / 1024)
		tmp_swap=$(expr "$(cat /sys/fs/cgroup/memory$cgrouppath/memory.memsw.limit_in_bytes)" - "$(cat /sys/fs/cgroup/memory$cgrouppath/memory.limit_in_bytes)")
		total_swap=$(echo "scale=2; $(echo $tmp_swap) / 1024 / 1024 / 1024" | bc -l)
		total_cpu=$(expr "$(cat /sys/fs/cgroup/cpu$cgrouppath/cpu.cfs_quota_us)" / "$(cat /sys/fs/cgroup/cpu$cgrouppath/cpu.cfs_period_us)")
		system_os=$(cat $rootfs_path/rootfs/etc/redhat-release)

		image_name=$(echo "$IMAGES_INFO" | grep "$(docker inspect $i --format {{.Image}} | awk -F ':' '{print $2}' | cut -b 1-12)" | head -1 | awk '{print $1":"$2}')
		c_total_mem=$(($c_total_mem + $total_mem))
		c_total_cpu=$(($c_total_cpu + $total_cpu))

		printf "\033[41;37m ----------------------------------- %s -------------------------------------- \033[0m\n" "$i"
		printf "hostname    : %-48s\n" $host_name
		echo "os          : $system_os"
		echo "image       : $image_name"
		printf "dm_device   : system %-12s       data %-12s [%s]\n" $system_disk $data_disk $volume_type
		printf "readahead   : system %-12s       data %-12s\n" $system_disk_readahead $data_disk_readahead
		printf "maxsectors  : system %-12s       data %-12s\n" $system_disk_maxsect $data_disk_maxsect
		echo "cpu         : $total_cpu"
		echo "mem         : $total_mem""G"
		echo "swap        : $total_swap""G"
		echo "read_bps    : $read_bps"
		echo "write_bps   : $write_bps"
		echo "read_iops   : $read_iops"
		echo "write_iops  : $write_iops"
		echo "cpuset_cpus : $cpuset_cpus"
		echo "cpuset_mems : $cpuset_mems"
		echo "wmark_ratio : $wmark_ratio"
		echo "high_wmark  : $high_wmark""M"
		echo "low_wmark   : $low_wmark""M"
		echo "created     : $created"
		echo "started     : $started"
		echo "rootfs_path : $rootfs_path/rootfs"
		echo "volume_path : $volume_path"
		echo "cgroup_path : /sys/fs/cgroup/{}$cgrouppath"
	done

	if [ ! -z "$CONTAINER_NAME" ]; then
		if [ "$flag" = "0" ]; then
			echo "$CONTAINER_NAME 容器没有找到"
			exit 1
		fi
		exit 0
	fi

	printf "\033[41;37m -----------------------------------host-------------------------------------- \033[0m\n"
	host_total_cpu=$(cat /proc/cpuinfo | grep processor | wc -l)
	host_total_mem=$(($(cat /proc/meminfo | grep MemTotal | awk '{print $2}') / 1024 / 1024))
	overbook_cpu=$(echo "scale=2; $c_total_cpu/$host_total_cpu" | bc)
	overbook_mem=$(echo "scale=2; $c_total_mem/$host_total_mem" | bc)

	echo "container_total_cpu   : $c_total_cpu"
	echo "host_total_cpu        : $host_total_cpu"
	echo "overbook_cpu          : $overbook_cpu"
	echo ""
	echo "container_total_mem   : $c_total_mem"
	echo "host_total_mem        : $host_total_mem"
	echo "overbook_mem          : $overbook_mem"
	echo ""
	echo "app_cores             : $(cat /var/hulk/hulk_app_cores)"
}

while getopts "s:h" opt; do
	case "$opt" in
	s)
		if [ -z "$OPTARG" ]; then
			echo "执行出错: -s 参数不能为空"
			usage 1
		fi

		CONTAINER_NAME="$OPTARG"
		;;
	h)
		usage 0
		;;
	*)
		usage 1
		;;
	esac
done

do_start
