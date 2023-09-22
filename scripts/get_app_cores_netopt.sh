#!/usr/bin/env bash
#
# Copyright (c) 2019 Meituan Corporation
#

app_log()
{
    cur_time=`date "+%Y-%m-%d-%H:%M:%S"`
    echo "[$cur_time] $1" >> $app_cores_log
}

#output the complete core list
format_data()
{
    cpulist=$1
    CORES=$( echo $cpulist | sed 's/,/ /g' | wc -w )
    for word in $(seq 1 $CORES)
    do
        SEQ=$(echo $cpulist | cut -d "," -f $word | sed 's/-/ /')
        if [ "$(echo $SEQ | wc -w)" != "1" ]
        then
                CPULIST="$CPULIST $( echo $(seq $SEQ) | sed 's/ /,/g' )"
        else
                CPULIST="$CPULIST $SEQ"
        fi
    done
    if [ "$CPULIST" != "" ]; then
        cpulist=$(echo $CPULIST | sed 's/ /,/g')
    fi
    echo $cpulist
}

# get the cpu list in $1 numa node
get_numa_cpulist()
{
    node=$1
    cpulist=$(cat /sys/devices/system/node/${node}/cpulist )

    if [ "$(echo $?)" != "0" ]; then
        app_log "Node id '$node' does not exists."
        exit 1
    fi

    format_data $cpulist

}

get_config()
{
   #the cpu core number for irq
   if [ $# -eq "1" ];then
     irqCores=$1
   else
     irqCores=8
   fi
   #the cpu cores for HULK,two choice: all/rest
   hulkCores="rest"
   #is the irqCores request to be in same numa node or not
   sameNumaNode="true"
   #auto switch hulk cpu cores or not
   autoSwitch="on"

   app_log "irqCores: $irqCores"
   app_log "hulkCores: $hulkCores"
   app_log "sameNumaNode: $sameNumaNode"
   app_log "autoSwitch: $autoSwitch"

   #get the total core number
   hostCores=$(cat /proc/cpuinfo | grep processor | wc -l)
   hostLastCoreNum=$(($hostCores-1))

   #make sure irqCores <= hostCores
   if [ "$irqCores" -gt "$hostCores" ]
   then
     app_log "config error: irqCores > hostCores"
     exit 1
   fi

   node_num=`lscpu|grep "NUMA node(s):"|awk '{print $3}'`
   node0_cpulist=$(get_numa_cpulist node0)
   if [ $node_num -eq 1 ]; then
     node1_cpulist=""
   else
     tmp_loop=$node_num;
     while [ $tmp_loop -gt 1 ];
     do
       tmp_loop=`expr $tmp_loop - 1`
       tmp_cpulist=$(get_numa_cpulist "node"$tmp_loop)
       if [ -z $node1_cpulist ]; then
          node1_cpulist=$(echo "$tmp_cpulist")
       else
          node1_cpulist=$(echo "$node1_cpulist,$tmp_cpulist")
       fi
     done
   fi

   #irqCores must be in the same numa node 
   if [ "$sameNumaNode"  == "true" ]
   then
      node0_cpucores=$(echo $node0_cpulist | sed 's/,/ /g' | wc -w)

      #make sure irqCores <= node0_cpucores
      if [ "$irqCores" -ge "$node0_cpucores" ]
      then
         irqCores=$node0_cpucores
         irq_cpu=$node0_cpulist
         hulk_cpu=$node1_cpulist
      else
         # get the first n core in node0 for irq,all the left cores will be used for HULK APP
         irq_cpu=$(echo $node0_cpulist | cut -d ',' --output-delimiter=',' -f 1-$irqCores)
         hulk_cpu=$(echo $node0_cpulist | cut -d ',' --output-delimiter=',' -f $(($irqCores+1))-$node0_cpucores)
         hulk_cpu=$(echo "$hulk_cpu,$node1_cpulist")
      fi
   else
      # if not request the irqCores in the same numa node,just the the first n cores 
      irq_cpu=$(echo `seq 0 $(($irqCores-1))` | sed 's/ /,/g')
      hulk_cpu=$(echo `seq $irqCores $hostLastCoreNum` | sed 's/ /,/g')
   fi

   if [ "$hulkCores" == "rest" ]
   then
      #sort
      hulkCores=$(echo `echo $hulk_cpu | sed 's/,/\n/g' | sort -n` | sed 's/ /,/g')
   elif [ "$hulkCores" == "all" ]
   then
      #hulk app can run in any core
      hulkCores=$(echo `seq 0 $hostLastCoreNum` | sed 's/ /,/g')
   else
     app_log "config error: hulkCores option config error, should only be rest or all."
     exit 1
   fi
	echo $hulkCores
}

app_cores_log="/var/hulk/app-cores.log"
hulk_app_cores="/var/hulk/hulk_app_cores"
mkdir -p /var/hulk/

# The default cluster
cluster=""

# Helper function to output usage
usage() {
	cat <<EOT
Overview:
	Generate the $hulk_app_cores

Usage:
	$0 [options] 

Options:
	-c	: The cluster
	-h      : Display this help.
EOT
}

main() {
	if [ $UID -ne 0 ]; then
		app_log "please run this with root" 
		exit 1
	fi

	while getopts "c:h" opt; do
		case "$opt" in
		c)
			cluster="${OPTARG}"
			;;
		h)
			usage
			exit 0
			;;
		esac
	done

	case "${cluster}" in
	squirrel)
		total_cores=$(cat /proc/cpuinfo | grep processor | wc -l)
		last_core=$(($total_cores - 1))
      		app_cores=$(echo `seq 0 $last_core` | sed 's/ /,/g')
		;;
	mysql)
		app_cores=`get_config 4`
		;;
	*)
		if [ -f $hulk_app_cores ]; then
			app_log "Using existing hulk_app_cores file"
			app_cores=$(cat $hulk_app_cores)
		fi
		if [ -z $app_cores ]; then
			total_cores=$(cat /proc/cpuinfo | grep processor | wc -l)
			if [ $total_cores -lt 96 ]; then
				app_log "Total cores less than 96"
				app_cores=`get_config 4`
			else
				app_log "Total cores larger than 96"
				app_cores=`get_config 6`
			fi
		fi
		;;
	esac
	echo $app_cores > $hulk_app_cores
	app_log $app_cores
	app_log "DONE"
}

main $@
