#!/bin/bash

# set -x

#
# config network for docker conntainer with --net=none option
# reference: https://github.com/jpetazzo/pipework
#
OPTYPE=$1
GUESTNAME=$2
IMAGENAME=$3
GUEST_IP=$4

IFNAME=br0
CONTAINER_IFNAME=eth1
FAMILY_FLAG="-4"

function try_exec() {
	$@
	if [ $? -ne 0 ]
	then
		exit 1
	fi
}

function create() {
	GATEWAY=`route -n | grep $IFNAME | grep UG | awk '{print $2}'`
	if [ $? -ne 0 ]
	then
		exit 1
	fi
	try_exec docker run -itd --privileged --cpus="4" --memory="8g" -v /dev/pk_drv:/dev/pk_drv --net=none --name ${GUESTNAME} 0b5567b2b43a

	DOCKERPID=`docker inspect --format='{{ .State.Pid }}' "$GUESTNAME"`
	if [ $? -ne 0 ]
	then
		exit 1
 	fi
	DOCKERCID=`docker inspect --format='{{ .ID }}' "$GUESTNAME"`
	if [ $? -ne 0 ]
        then
                exit 1
        fi

	DOCKERCNAME=`docker inspect --format='{{ .Name }}' "$GUESTNAME"`
	if [ $? -ne 0 ]
    then
		exit 1
	fi


	NSPID=$DOCKERPID

	LOCAL_IFNAME="v${CONTAINER_IFNAME}pl${NSPID}"
	GUEST_IFNAME="v${CONTAINER_IFNAME}pg${NSPID}"
	MTU=`ip link show "$IFNAME" | awk '{print $5}'`
	if [ $? -ne 0 ]
    then
    	exit 1
    fi

	#
	try_exec mkdir -p /var/run/netns
	try_exec rm -f "/var/run/netns/$NSPID"
	try_exec ln -s "/proc/$NSPID/ns/net" "/var/run/netns/$NSPID"

	# create veth-pair
	try_exec ip link add name "$LOCAL_IFNAME" mtu "$MTU" type veth peer name "$GUEST_IFNAME" mtu "$MTU"
	try_exec ip link set "$LOCAL_IFNAME" master "$IFNAME" > /dev/null 2>&1
	try_exec ip link set "$LOCAL_IFNAME" up

	# set veth-pair with container namespace
	try_exec ip link set "$GUEST_IFNAME" netns "$NSPID"
	try_exec ip netns exec "$NSPID" ip link set "$GUEST_IFNAME" name "$CONTAINER_IFNAME"
	try_exec ip netns exec "$NSPID" ip link set $CONTAINER_IFNAME up
	try_exec ip netns exec "$NSPID" ip addr add $GUEST_IP/24 dev $CONTAINER_IFNAME
	#try_exec ip netns exec "$NSPID" ip route add 10.82.59.0/24 dev $CONTAINER_IFNAME
	try_exec ip netns exec "$NSPID" ip route add default via 10.82.59.1
	
	# FROM centos:7
	# RUN yum install -y net-tools dhclient
	#try_exec docker run -itd --privileged --cpus="4" --memory="8g" -v /dev/pk_drv:/dev/pk_drv --ip=$GUEST_IP --net container:$GUESTNAME --name ${GUESTNAME} 0b5567b2b43a
	#try_exec docker exec -it ${GUESTNAME}_dhcp dhclient $CONTAINER_IFNAME >/dev/null

	GUEST_HOSTNAME=$(docker exec -it ${GUESTNAME} cat /etc/hostname)
	if [ -n "$GUEST_IP" ] && [ -n "$GUEST_HOSTNAME" ]; then
		docker exec -it ${GUESTNAME} bash -c "echo '$GUEST_IP $GUEST_HOSTNAME' >> /etc/hosts"
	fi
	# Remove NSPID to avoid `ip netns` catch it.
	try_exec rm -f "/var/run/netns/$NSPID"
}

function delete() {
	stat=` docker inspect --format {{.State.Status}} ${GUESTNAME}`
#	if [ "$stat" = "running" ]; then
#		try_exec docker exec -it ${GUESTNAME}_dhcp dhclient -r $CONTAINER_IFNAME
#	fi
	try_exec docker rm -f $GUESTNAME ${GUESTNAME}
}

function main() {
        if [ $# -lt 2 ] 
        then
		echo "Usage:"
		echo "  dockerx run name image ip"
		echo "  dockerx rm name"
		exit 1
        fi
	if [ -z "$OPTYPE" ]
	then
		echo "Usage:"
		echo "  dockerx run name image ip"
		echo "  dockerx rm name"
		exit 1
	elif [ $OPTYPE = "run" ]
	then
		if [ -z "$GUESTNAME" ] && [ -z "$IMAGENAME" ]
		then
			exit 1
		else
			create
		fi
	elif [ $OPTYPE = "rm" ]
	then
		if [ -z "$GUESTNAME" ]
		then
			exit 1
		else
			delete
		fi
	else
		exit 1
	fi
	exit 0
}

main $@
