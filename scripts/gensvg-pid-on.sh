#!/usr/bin/bash

if [[ $# != 1 ]] ; then
   echo "USAGE:CMD <process pid>"
   exit
fi

host_name=`hostname`
profile_time=`date '+%T'`
perf record -F 99 -p $1 -g -- sleep 60
perf script > out.perf

#wget https://kernel.sankuai.com/tools/flamegraph/FlameGraph.tgz
#tar -xzvf FlameGraph.tgz
./FlameGraph/stackcollapse-perf.pl out.perf > out.folded
./FlameGraph/flamegraph.pl out.folded > $host_name-$profile_time-pidon.svg
#rm ./FlameGraph.tgz
rm out.perf out.folded perf.data
