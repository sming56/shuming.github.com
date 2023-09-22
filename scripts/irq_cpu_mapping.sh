#/usr/bin/bash

echo hostname: `hostname`
num=
#128 cpus at maxium
cpu_map=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
cpu_map_net=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
cpu_map_vfs=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
for IRQ in `ls -1 /proc/irq/`
do
   if [[ ! -f "/proc/irq/$IRQ/effective_affinity_list" ]]; then
      if [[ ! -f "/proc/irq/$IRQ/smp_affinity_list" ]]; then
         continue
      fi
      str=$((`cat /proc/irq/$IRQ/smp_affinity_list`))
      case "$str" in
         [0-9]*)
             num=$((`cat /proc/irq/$IRQ/smp_affinity_list`))
             ;;
         *)
             continue
             ;;
      esac
   else
      num=$((`cat /proc/irq/$IRQ/effective_affinity_list`))
   fi
#   echo CPU: cpu$num, IRQ$IRQ
   cpu_map[$num]=$((cpu_map[$num]+1))
done
for i in {0..127}
do
    echo CPU$i: ${cpu_map[$i]}
done

ALL_NICS=`cat /proc/net/dev | grep ":" | awk -F: '{print $1}' | grep -v -E 'bond0|br0|lo|docker0|ovs-system|ovs0|ovs-gretap0|ovs-ip6gre0|ovs-ip6tnl0|erspan0|veth*' | sort`
echo ALL_NICS: $ALL_NICS

for DEV in $ALL_NICS
do
    for IRQ in `ls -1 /sys/class/net/$DEV/device/msi_irqs/ 2>/dev/null` 
    do
        if [[ ! -f "/proc/irq/$IRQ/effective_affinity_list" ]]; then
           if [[ ! -f "/proc/irq/$IRQ/smp_affinity_list" ]]; then
	      continue
           fi
           str=$((`cat /proc/irq/$IRQ/smp_affinity_list`))
           case "$str" in
           [0-9]*)
              num=$((`cat /proc/irq/$IRQ/smp_affinity_list`))
              ;;
           *)
              continue
              ;;
           esac
        else
           num=$((`cat /proc/irq/$IRQ/effective_affinity_list`))
#        echo Net_CPU: cpu$num, IRQ$IRQ
        fi
        cpu_map_net[$num]=$((cpu_map_net[$num]+1))
    done
done
for i in {0..127}
do
    echo NET_CPU$i: ${cpu_map_net[$i]}
done

rpm -q mnic-init > /dev/null
if [ $? -ne 0 ]; then
    echo "not mnic machine"
    exit 0
fi

cat /proc/net/dev | grep ovs0 > /dev/null
if [ $? -ne 0 ]; then
    echo "not mnic machine"
    exit 0
fi

for docker in `docker ps | grep k8s_app | awk -F ' ' '{print $1}'`
do
    for IRQ in `docker exec $docker ls -1 /sys/class/net/eth0/device/msi_irqs`
    do
        if [[ ! -f "/proc/irq/$IRQ/effective_affinity_list" ]]; then

           if [[ ! -f "/proc/irq/$IRQ/smp_affinity_list" ]]; then
              continue
           fi
           str=$((`cat /proc/irq/$IRQ/smp_affinity_list`))
           case "$str" in
           [0-9]*)
              num=$((`cat /proc/irq/$IRQ/smp_affinity_list`))
              ;;
           *)
              continue
              ;;
           esac
	else
            num=$((`cat /proc/irq/$IRQ/effective_affinity_list`))
        fi
#        echo Net_VF_CPU: cpu$num, IRQ$IRQ
        cpu_map_vfs[$num]=$((cpu_map_vfs[$num]+1))

    done
done
for i in {0..127}
do
    echo NET_VF_CPU$i: ${cpu_map_vfs[$i]}
done

