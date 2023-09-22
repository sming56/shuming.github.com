#!/bin/bash
sum=0
index=1
num_objs=0
for info in `cat /sys/fs/cgroup/memory/memory.kmem.slabinfo  | sed -e '1,2d' | awk '{ print $3,$4 }'`
do
   steps=$(echo "$index % 2" | bc)
   if [ $steps == 0 ]; then
      sum=$(echo "$sum + $num_objs * $info" | bc)
   else
      num_objs=$info
   fi
   echo "num_objs=$num_objs, steps=$steps, sum=$sum, info=$info"

   index=$(echo "$index + 1" | bc)
done
sum=$(echo "$sum / 1024 /1024 " | bc)
echo "The total memory is ${sum}M."
