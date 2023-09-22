#!/usr/bin/bash

if [ $# -ne 1 ]
then
     echo "Usage: command <k8s_name>"
     exit 1
fi


k8s_name=$1
counter=0
output_file=$k8s_name"_host_list.txt"

query_result=`curl --request GET --url http://nodemanager.hulk.vip.sankuai.com/api/v1/host?clusterName=$k8s_name`
res_len=${#query_result}
query_result=${query_result#*\"hostname\":}
res_len_cut=${#query_result}
#while [ -n $query_result ]  -a  [ counter < 10 ];
while [[ $res_len !=  $res_len_cut ]];
do
	host_name=${query_result%%,\"status\":*}
	echo $host_name >> $output_file
	query_result=${query_result#*\"hostname\":}
	res_len=$res_len_cut
	res_len_cut=${#query_result}
done


