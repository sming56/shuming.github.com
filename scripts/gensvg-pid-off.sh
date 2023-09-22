#!/usr/bin/bash

if [[ $# != 1 ]] ; then
   echo "USAGE:CMD <process pid>"
   exit
fi

host_name=`hostname`
profile_time=`date '+%T'`
/usr/share/bcc/tools/offcputime -df  -p $1  60 > offline-pid.stacks

#wget https://kernel.sankuai.com/tools/flamegraph/FlameGraph.tgz
#tar -xzvf FlameGraph.tgz
FlameGraph/flamegraph.pl --color=io --title="Off-CPU Time Flame Graph"  --countname=us < offline-pid.stacks > offline-pid.svg
#rm ./FlameGraph.tgz
rm offline-pid.stacks
