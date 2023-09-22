#!/usr/bin/bash

if [[ $# != 0 ]] ; then
   echo "USAGE:CMD"
   exit
fi

host_name=`hostname`
profile_time=`date '+%T'`
/usr/share/bcc/tools/offcputime -df 60 > offline-all.stacks

#wget https://kernel.sankuai.com/tools/flamegraph/FlameGraph.tgz
#tar -xzvf FlameGraph.tgz
FlameGraph/flamegraph.pl --color=io --title="Off-CPU Time Flame Graph"  --countname=us < offline-all.stacks > offline-all.svg
#rm ./FlameGraph.tgz
rm offline-all.stacks
