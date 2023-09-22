#!/bin/bash

hulk_cpu=
irq_cpu=
ALL_HOST_NICS=

max_mask_length=144

irq_log="/var/hulk/irq-consolidate.log"
hulk_irq_cores="/var/hulk/hulk_irq_cores"
hulk_app_cores="/var/hulk/hulk_app_cores"

irq_log()
{
    cur_time=`date "+%Y-%m-%d-%H:%M:%S"`
    echo "[$cur_time] $1" | tee -a $irq_log
}

get_config()
{
   local hostCores
   local hulkCores
   local sameNumaNode
   local autoSwitch
   local hostLastCoreNum
   local node_num
   local tmp_loop 
   local node0_cpulist
   local node1_cpulist
   

   #get the total core number
   hostCores=$(cat /proc/cpuinfo | grep processor | wc -l)
   hostLastCoreNum=$(($hostCores-1))
   #the cpu core number for irq
   if [ $# -eq "1" ];then
     irqCores=$1
   else
     #keep the same logic with get_app_cores.sh
     if [ $hostCores -lt 96 ];then
        irqCores=4
     else
        irqCores=6
     fi
   fi
   #the cpu cores for HULK,two choice: all/rest
   hulkCores="rest"
   #is the irqCores request to be in same numa node or not
   sameNumaNode="true"
   #auto switch hulk cpu cores or not
   autoSwitch="on"

   irq_log "irqCores: $irqCores"
   irq_log "hulkCores: $hulkCores"
   irq_log "sameNumaNode: $sameNumaNode"
   irq_log "autoSwitch: $autoSwitch"

   #make sure irqCores <= hostCores
   if [ "$irqCores" -gt "$hostCores" ]
   then
     irq_log "config error: irqCores > hostCores"
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
     irq_log "config error: hulkCores option config error, should only be rest or all."
     exit 1
   fi
}

#output the complete core list
format_data()
{

    local cpulist
    local CORES
    local SEQ
    local CPULIST

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
    local node
    local cpulist

    node=$1
    cpulist=$(cat /sys/devices/system/node/${node}/cpulist )

    if [ "$(echo $?)" != "0" ]; then
        irq_log "Node id '$node' does not exists."
        exit 1
    fi

    format_data $cpulist

}


#The mask is converted into a uniform length, which is convenient for comparison
#举例：
#（1）输入参数 400             输出结果：000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400
#（2）输入参数 0000,00000400   输出结果：000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400
irq_cores_convert()
{
    local irq_cores_mask
    local base_cores
    local irq_cores_arr
    local num_length
    local compute_num

    irq_cores_mask=$1
    base_cores="000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    irq_cores_arr=(`echo ${irq_cores_mask} | sed 's/,//g' | sed s/[[:space:]]//g`)
    num_length=`echo ${irq_cores_arr} | wc -L`
    if [ ${num_length} -lt $max_mask_length ]; then
        compute_num=`echo ${base_cores:${num_length}}"${irq_cores_arr}"`
    fi
    echo $compute_num
}

#MASK超过8位时，每8位之间添加一个逗号
#输入参数 400                输出结果：400
#输入参数 8000000000000000   输出结果：80000000,00000000
mask_to_smp_affinity()
{
    local mask
    local mask_length
    local mask_result
    local smp_affinity_length
    local flag
    local mask_arr
    local mask_result
    local i
    local last_length

    mask=$1
    mask_length=`echo $1 | wc -L`
    mask_result=()
    if [ $mask_length -gt "8" ]; then
        smp_affinity_length=`expr $mask_length / 8`
        flag=8
        for i in $(seq 1 $smp_affinity_length)
        do
            mask_arr=`echo ${mask:0-$flag:8}`
            mask_result=(","$mask_arr"${mask_result[@]}")
            flag=`expr $flag + 8`
            i=`expr $i + 1`
        done
        if [ `expr $mask_length % 8` -eq "0" ]; then
            echo ${mask_result#*,}
        else
            last_length=`expr $mask_length - $smp_affinity_length \* 8`
            mask_arr=`echo ${mask:0:$last_length}`
            mask_result=($mask_arr"${mask_result[@]}")
            echo $mask_result
        fi
    else
        echo $1
    fi
}

#output current irq_affinity
check_host_irq_affinity()
{
    # output available nic's current irq affinity map
    for DEV in $ALL_HOST_NICS
    do
	for IRQ in `ls -1 /sys/class/net/$DEV/device/msi_irqs/ 2>/dev/null`
        do
	    if [[ ! -f "/proc/irq/$IRQ/smp_affinity_list" ]]; then
		    continue
	    fi
            cat /proc/irq/$IRQ/smp_affinity_list
        done
    done
}

set_host_irq_affinity()
{
   echo set_host_irq_affinity-ALL_HOST_NICS: $ALL_HOST_NICS
   echo cpu num: $2

    # VEC = VECTMP % irqCores
    local VEC=0
    # VECTMP is the total loop number
    local VECTMP=0
    local MASK_TMP
    local MASK

    for DEV in $ALL_HOST_NICS
    do
        irq_log "set_host_irq_affinity NIC:$DEV "

        # get the irq
	for IRQ in `ls -1 /sys/class/net/$DEV/device/msi_irqs/ 2>/dev/null`
        do
            # choise the core
            MASK_TMP=$(echo $1 | cut -d ',' -f $(($VEC+1)))
            MASK_TMP=$((1<<$MASK_TMP))
            MASK=`printf "%X" $MASK_TMP`
	    MASK=`echo $(mask_to_smp_affinity $MASK)`
	    MASK=`printf "%s" $MASK`
	    printf "%s first mask=%s for /proc/irq/%d/smp_affinity\n" $DEV $MASK $IRQ
	    if [[ ! -f "/proc/irq/$IRQ/smp_affinity" ]]; then
		    continue
	    fi
            printf "Before MASK = %s\n" $MASK
            cat /proc/irq/$IRQ/smp_affinity
            printf "%s" $MASK > /proc/irq/$IRQ/smp_affinity
            cat /proc/irq/$IRQ/smp_affinity
	    #confirm whether the smp_affinity setting is successful,if not,set the interrupt to next cpucore
            retry=3
            while [ `echo $(irq_cores_convert $MASK)` != `echo $(irq_cores_convert $(cat /proc/irq/$IRQ/smp_affinity))` ]
            do
                VECTMP=`expr $VECTMP + 1`
                VEC=`expr $VECTMP % $2`
                MASK_TMP=$(echo $1 | cut -d ',' -f $(($VEC+1)))
                MASK_TMP=$((1<<$MASK_TMP))
                MASK=`printf "%X" $MASK_TMP`
	        MASK=`echo $(mask_to_smp_affinity $MASK)`
                MASK=`printf "%s" $MASK`
                printf "%s next mask=%s for /proc/irq/%d/smp_affinity\n" $DEV $MASK $IRQ
                printf "Before MASK = %s\n" $MASK
                cat /proc/irq/$IRQ/smp_affinity
                printf "%s" $MASK > /proc/irq/$IRQ/smp_affinity
                cat /proc/irq/$IRQ/smp_affinity
                retry=`expr $retry - 1`
                if [ "$retry" -eq 0 ]; then
                   printf "Max times retried\n"
                   break
                fi
            done
            # adjust the next loop's VECTMP VEC
            VECTMP=`expr $VECTMP + 1`
            VEC=`expr $VECTMP % $2`
         done
         irq_log "finished setting nic $DEV"
     done
}

get_host_nic_list()
{

    ALL_HOST_NICS=`cat /proc/net/dev | grep ":" | awk -F: '{print $1}' | grep -v -E 'bond0|br0|lo|docker0|ovs-system|ovs0|ovs-gretap0|ovs-ip6gre0|ovs-ip6tnl0|erspan0|veth*' | sort`

    echo $ALL_HOST_NICS
}


function set_vf_irq_affinity()
{
    local vec
    local vec_tmp
    local mask_tmp
    local mask
    local num

    # vec = vec_tmp % irq_cores
    vec=0
    # vec_tmp is the total loop number
    vec_tmp=0
    irq_cores=$2

    for docker in `docker ps | grep k8s_app | awk -F ' ' '{print $1}'`
    do
        # get the irq
        for irq in `docker exec $docker ls -1 /sys/class/net/eth0/device/msi_irqs`
        do
            # choise the core
            mask_tmp=$(echo $1 | cut -d ',' -f $(($vec+1)))
            mask_tmp=$((1<<$mask_tmp))
            mask=`printf "%X" $mask_tmp`
            mask=`echo $(mask_to_smp_affinity $mask)`
            mask=`printf "%s" $mask`
            printf "mask=%s for /proc/irq/%d/smp_affinity\n" $mask $irq
            if [[ ! -f "/proc/irq/$irq/smp_affinity" ]]; then
                    continue
            fi

            printf "%s mask=%s for /proc/irq/%d/smp_affinity\n" $DEV $mask $irq
            cat /proc/irq/$IRQ/smp_affinity
            printf "%s" $mask > /proc/irq/$irq/smp_affinity
            cat /proc/irq/$IRQ/smp_affinity
            #confirm whether the smp_affinity setting is successful,if not,set the interrupt to next cpucore
            num=0
            retry=3
            while [ `echo $(irq_cores_convert $mask)` != `echo $(irq_cores_convert $(cat /proc/irq/$irq/smp_affinity))` ]
            do
                if [ $num -gt $irq_cores ]; then
                    echo "no lcore can bind irqs"
                    exit 1
                fi
                num=`expr $num + 1`
                vec_tmp=`expr $vec_tmp + 1`
                vec=`expr $vec_tmp % $2`
                mask_tmp=$(echo $1 | cut -d ',' -f $(($vec+1)))
                mask_tmp=$((1<<$mask_tmp))
                mask=`printf "%X" $mask_tmp`
                mask=`echo $(mask_to_smp_affinity $mask)`
                mask=`printf "%s" $mask`
                printf "%s mask=%s for /proc/irq/%d/smp_affinity\n" $DEV $mask $irq
                cat /proc/irq/$IRQ/smp_affinity
                printf "%s" $mask > /proc/irq/$irq/smp_affinity
                cat /proc/irq/$IRQ/smp_affinity

                retry=`expr $retry - 1`
                if [ "$retry" -eq 0 ]; then
                   printf "Max times retried\n"
                   break
                fi
            done
            # adjust the next loop's vec_tmp vec
            vec_tmp=`expr $vec_tmp + 1`
            vec=`expr $vec_tmp % $2`
         done
         echo "finished setting docker $docker"
     done
}

function check_vf_irq_affinity()
{
    local vec
    local vec_tmp

    # vec = vec_tmp % irq_cores
    vec=0
    # vec_tmp is the total loop number
    vec_tmp=0

    for docker in `docker ps | grep k8s_app | awk -F ' ' '{print $1}'`
    do
        # get the irq
        for irq in `docker exec $docker ls -1 /sys/class/net/eth0/device/msi_irqs`
        do
            if [[ ! -f "/proc/irq/$irq/smp_affinity" ]]; then
                    continue
            fi
	    cat /proc/irq/$irq/smp_affinity
        done
    done
}


#step 1
#get current CPU configs

if [ $# != 1 ]; then
    echo "get_config without parameter"
    get_config
else
    echo "get_config $1"
    get_config $1
fi
get_host_nic_list
echo ALL_HOST_NICS: $ALL_HOST_NICS

hulk_total_cores=$(echo $hulk_cpu | sed 's/,/ /g' | wc -w)
echo hulk_total_cores: $hulk_total_cores
check_host_irq_affinity > /tmp/irq_host_affinity

irqHostCurrentCores=$(echo `sort -n /tmp/irq_host_affinity | uniq ` | sed 's/ /,/g')

#step 2
#set the CPU binding for PF nics and VF nics not assigned in the host
if [ "$irqHostCurrentCores" != "$irq_cpu" ]
then
    irq_log "begin to adjust host irq affinity"
    irq_log "current irqCores: $irqHostCurrentCores"
    irq_log "target irqCores: $irq_cpu"
    #disperse the irq to hulk cpu and clean the irq cpus
    set_host_irq_affinity $hulk_cpu $hulk_total_cores
    set_host_irq_affinity $irq_cpu $irqCores
    echo
fi

echo $irq_cpu > $hulk_irq_cores
echo $hulk_cpu > $hulk_app_cores

rpm -q mnic-init > /dev/null
if [ $? -ne 0 ]; then
    exit 0
fi

cat /proc/net/dev | grep ovs0 > /dev/null
if [ $? -ne 0 ]; then
    exit 0
fi
echo `hostname`": setting VFs"
check_vf_irq_affinity > /tmp/irq_vf_affinity

#step 3
#set the CPU binding for the VF nics assigned in the host
irqVFCurrentCores=$(echo `sort -n /tmp/irq_vf_affinity | uniq ` | sed 's/ /,/g')
if [ "$irqVFCurrentCores" != "$irq_cpu" ]
then
    irq_log "begin to adjust vf irq affinity"
    irq_log "current irqCores: $irqVFCurrentCores"
    irq_log "target irqCores: $irq_cpu"
    set_vf_irq_affinity $hulk_cpu $hulk_total_cores
    set_vf_irq_affinity $irq_cpu $irqCores
    echo
fi

