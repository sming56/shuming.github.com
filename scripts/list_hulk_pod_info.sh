#!/bin/bash

DOCKER_PS_TMP_FILE=".docker_ps_to_pod_info.file.tmp"

get_pod_info_by_container_id() {
	local container_id="$1"

	ROOT_PID=$(docker inspect --format '{{ .State.Pid }}' $container_id)
	if [ "$ROOT_PID" == "" ]; then
		ROOT_PID="null"
		HOST="null"
		IP="null"
		CPUSETS="null"
		continue
	fi

	HOST=$(nsenter -t $ROOT_PID -u hostname)
	IP=$(nsenter -t $ROOT_PID -n ip a |grep 'inet ' |grep -v '127.0.0.1' |grep -v '172.17.0.1' |awk '{print $2}' |cut -d '/' -f 1 |xargs)
	IP=${IP// /,}

	UPTIME=$(nsenter -t $ROOT_PID -p uptime |cut -d ',' -f 1 |awk -F 'up' '{print $2}' |awk '$1=$1' |sed 's# #_#g')
	if [ -z "$UPTIME" ]; then
		UPTIME="null"
	fi

	CPUSET_PATH=$(cat /proc/$ROOT_PID/cgroup |grep cpuset |cut -d ':' -f 3)
	CPUSETS=$(cat /sys/fs/cgroup/cpuset/$CPUSET_PATH/cpuset.cpus)

	local container_veth_id=$(nsenter -t $ROOT_PID -n ip a |grep "eth0@" |awk '{print $2}' |awk -F '@if' '{print $2}' |cut -d ':' -f 1)
	CONTAINER_VETH=$(ip a |grep "^$container_veth_id:" |awk '{print $2}' |cut -d '@' -f 1)
	if [ -z "$CONTAINER_VETH" ]; then
		CONTAINER_VETH="null"
	fi

	if nsenter -t $ROOT_PID -m -p df -h /docker 2>/dev/null |grep -E "^/dev/sd.*" >/dev/null; then
		DISK_TYPE="ebs"
	else
		DISK_TYPE="lvm"
	fi

	get_container_cpu_num
	get_container_mem_size
	get_container_data_disk_size
	get_container_os_version
}

get_container_cpu_num() {
	local cpu_cgroup_path=$(cat /proc/$ROOT_PID/cgroup |grep "cpuacct" |cut -d ':' -f 3)
	local cfs_period_us=$(cat /sys/fs/cgroup/cpu,cpuacct/$cpu_cgroup_path/cpu.cfs_quota_us)
	local cfs_quota_us=$(cat /sys/fs/cgroup/cpu,cpuacct/$cpu_cgroup_path/cpu.cfs_period_us)
	if [ $cfs_period_us -eq -1 ]; then
		CPU_NUM=$(lscpu |grep "^CPU(s):" |awk '{print $2}')
	else
		let "CPU_NUM=$cfs_period_us/$cfs_quota_us"
	fi
}

get_container_mem_size() {
	local mem_cgroup_path=$(cat /proc/$ROOT_PID/cgroup |grep "memory" |cut -d ':' -f 3)
	local limit_in_bytes=$(cat /sys/fs/cgroup/memory/$mem_cgroup_path/memory.limit_in_bytes)
	let "MEM_SIZE_GB=$limit_in_bytes/1024/1024/1024"
	if [ $MEM_SIZE_GB -gt 9999 ]; then
		MEM_SIZE_GB=$(free -g |grep Mem: |awk '{print $2}')
	fi
}

get_container_data_disk_size() {
	DISK_SIZE=$(nsenter -t $ROOT_PID -p -m df -h /opt 2>/dev/null |grep -v Filesystem |xargs |awk '{print $2}')
	if [ -z "$DISK_SIZE" ]; then
		DISK_SIZE="0G"
	fi
}

get_container_os_version() {
	OS_VERSION=$(nsenter -t $ROOT_PID -p -m cat /etc/redhat-release 2>/dev/null |grep -Eo "[0-9\.]*")
	if [ -z "$OS_VERSION" ]; then
		OS_VERSION="null"
	fi
}

is_kata_env() {
	if cat /root/.container_config 2>/dev/null |grep containerEngine=containerd >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

list_hulk_pod_info() {
	if is_kata_env; then
		crictl pods
		return
	fi

	{
		if [ "$1" == "short" ]; then
			echo "ROOT_PID CONTAINER_ID HOSTNAME IP CPU_MEM_DISK CPUSET"
		else
			echo "ROOT_PID CONTAINER_VETH CONTAINER_ID HOSTNAME IP CPU_MEM_DISK OS_VERSION UPTIME DISK_TYPE CPUSET"
		fi

		CONTAINERS=$(docker ps |grep -v 'CONTAINER ID' |grep -v 'pause-amd64' |awk '{print $1}')
		for CONTAINER_ID in $CONTAINERS; do
			get_pod_info_by_container_id $CONTAINER_ID
			if [ "$1" == "short" ]; then
				echo "$ROOT_PID $CONTAINER_ID $HOST $IP ${CPU_NUM}c${MEM_SIZE_GB}g_${DISK_SIZE} $CPUSETS"
			else
				echo "$ROOT_PID $CONTAINER_VETH $CONTAINER_ID $HOST $IP ${CPU_NUM}c${MEM_SIZE_GB}g_${DISK_SIZE} $OS_VERSION $UPTIME $DISK_TYPE $CPUSETS"
			fi
		done
	} | column -t
}

list_running_pods_info() {
	if is_kata_env; then
		crictl pods
		return
	fi
	{
		echo "ROOT_PID CONTAINER_ID HOSTNAME POD_NAMESPACE POD_NAME"

		docker ps |grep -v 'google_containers/pause-amd64' |grep -v 'CONTAINER ID' >$DOCKER_PS_TMP_FILE
		while read DOCKER_PS
		do
			CONTAINER_ID=$(echo $DOCKER_PS |awk '{print $1}')
			get_pod_info_by_container_id $CONTAINER_ID
			POD_NAME=$(echo $DOCKER_PS |grep -Eo 'k8s.*' |cut -d "_" -f 3)
			POD_NAMESPACE=$(echo $DOCKER_PS |grep -Eo 'k8s.*' |cut -d "_" -f 4)
			echo "$ROOT_PID $CONTAINER_ID $HOST $POD_NAMESPACE $POD_NAME"
		done < "$DOCKER_PS_TMP_FILE"
	} | column -t
}

list_exist_pods_info() {
	if is_kata_env; then
		crictl ps |grep -v "Running"
		return
	fi

	{
		echo "CONTAINER_ID K8S_NAMESPACE POD_NAME"
		docker ps -a |grep -v 'google_containers/pause-amd64' |grep -v 'CONTAINER ID' |grep "Exited" >$DOCKER_PS_TMP_FILE
		while read DOCKER_PS
		do
			CONTAINER_ID=$(echo $DOCKER_PS |awk '{print $1}')
			POD_NAME=$(echo $DOCKER_PS |grep -Eo 'k8s.*' |cut -d "_" -f 3)
			POD_NAMESPACE=$(echo $DOCKER_PS |grep -Eo 'k8s.*' |cut -d "_" -f 4)
			echo "$CONTAINER_ID $POD_NAMESPACE $POD_NAME"
		done < "$DOCKER_PS_TMP_FILE"
	} | column -t
}

get_containerid_by_pod_id() {
	if is_kata_env; then
		local container_id=$(crictl ps |grep "$1" |awk '{print $1}')
		if [ -n "$container_id" ]; then
			echo "$container_id"
			echo "# Run a command in $container_id, eg:" 1>&2
			echo "crictl exec -it $container_id bash" 1>&2
			return 0
		else
			return 1
		fi
	else
		echo "[ERROR] $0 -g command is only used for kata environment"
		exit 1
	fi
}

usage() {
	echo "
Usage:
	$0                  # default, like -l or --list

	$0 -h | --help      # show this help info

	$0 -l | --list      # list running container info, eg: veth,hostname,ip,cpu_mem_disk,os_version,uptime,disk_type,cpuset
	$0 -s | --short     # list running container info, short format
	$0 -k | --k8s       # list running container in k8s pod info
	$0 -e | --exit      # list not running container in k8s pod info, if it exist
	$0 -a | --all       # list all container in k8s pod info, include Exited container

	kata environment:
	# get POD_ID
	# $0
	# get container ID by POD_ID for kata environment
	$0 { -g | --getcid } POD_ID
	eg: 
		# $0 -g 880189c8eb089
		10dbb5870d1e6
		# Run a command in 10dbb5870d1e6, eg:
		crictl exec -it 10dbb5870d1e6 bash
"
}

if [ $# -gt 2 ]; then
	echo "[ERROR] too many arguments!"
	usage
	exit 1
fi

if [ "$(whoami)" != "root" ]; then
	echo "[ERROR] $0 must run with root user!"
	exit 1
fi

if [ "$1" == "" ]; then
	list_hulk_pod_info
else
	case "$1" in
	-h|--help)
		usage
		;;
	-l|--list)
		list_hulk_pod_info
		;;
	-s|--short)
		list_hulk_pod_info "short"
		;;
	-k|--k8s)
		list_running_pods_info
		;;
	-e|--exit)
		echo -e "\n\t# ********** NOT RUNNING POD INFO ********** #\n"
		list_exist_pods_info
		;;
	-a|--all)
		echo -e "\n\t# ************ RUNNING POD INFO ************ #\n"
		list_running_pods_info
		echo -e "\n\t# ********** NOT RUNNING POD INFO ********** #\n"
		list_exist_pods_info
		;;
	-g|--getcid)
		if [ -z "$2" ]; then
			usage
			exit 1
		else
			get_containerid_by_pod_id $2
		fi
		;;
	*)
		echo "[ERROR] argument error!"
		usage
		exit 1
		;;
	esac
fi
