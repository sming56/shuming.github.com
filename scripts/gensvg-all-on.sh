#!/usr/bin/bash

if [[ $# != 0 ]] ; then
   echo "USAGE:CMD"
   exit
fi

host_name=`hostname`
profile_time=`date '+%T'`
perf record -F 99 -a -g -- sleep 60
perf script > out.perf

#wget https://kernel.sankuai.com/tools/flamegraph/FlameGraph.tgz
#tar -xzvf FlameGraph.tgz
./FlameGraph/stackcollapse-perf.pl out.perf > out.folded
./FlameGraph/flamegraph.pl out.folded > $host_name-$profile_time-allon.svg
#rm ./FlameGraph.tgz
rm out.perf out.folded perf.data
