#!/usr/bin/bash

if [[ $# != 1 ]]; then
   echo "Usage: ./command <cpu num>"
fi

cat /proc/interrupts > /tmp/interrupts.txt

while read line
do
	interrupt_num=$(echo $line | awk  '{print $1}')
	device_name=$(echo $line | awk  '{print $130}')
	mod_name=$(echo $line | awk  '{print $132}')
	
	interrupt_num=$(echo $interrupt_num | sed -e 's/\://g')
	if [[ $interrupt_num =~ [0-9]+$ ]]; then
	   if [[ ! -f "/proc/irq/$interrupt_num/effective_affinity_list" ]]; then
              if [[ ! -f "/proc/irq/$interrupt_num/smp_affinity_list" ]]; then
              continue
           fi
           cpu_str=$((`cat /proc/irq/$interrupt_num/smp_affinity_list`))
           case "$str" in
              [0-9]+)
                 cpu_num=$((`cat /proc/irq/$interrupt_num/smp_affinity_list`))
                 ;;
              *)
                 continue
                 ;;
              esac
           else
              cpu_num=$((`cat /proc/irq/$interrupt_num/effective_affinity_list`))
	   fi
	   if [ $cpu_num == $1 ]; then
	      echo  "interrupt num = " $interrupt_num
	      echo  "mod name = " $mod_name
	      echo  "device name = " $device_name
	   fi
        fi

done < /tmp/interrupts.txt

