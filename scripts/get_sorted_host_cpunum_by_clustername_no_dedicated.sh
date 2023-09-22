#!/usr/bin/bash

if [ $# -ne 1 ]
then
     echo "Usage: command <k8s_name>"
     exit 1
fi


k8s_name=$1
counter=0
filter='48'
output_file=cpulists/$k8s_name"_host_cpunum.txt"
output_dedicated=cpulists/$k8s_name"_host_cpunum_dedicated.txt"

if [[ $k8s_name =~ "offline" ]]
then
	echo "Offline cluster: "$k8s_name
	query_result=`curl --request GET --url http://nodemanager.hulk.test.sankuai.com/api/v1/host?clusterName=$k8s_name`
else
	echo "Online cluster: "$k8s_name
	query_result=`curl --request GET --url http://nodemanager.hulk.vip.sankuai.com/api/v1/host?clusterName=$k8s_name`
fi
echo $query_result
res_len=${#query_result}
query_result=${query_result#*\"hostname\":}
res_len_cut=${#query_result}
#while [ -n $query_result ]  -a  [ counter < 10 ];
while [[ $res_len !=  $res_len_cut ]];
do
	host_name=${query_result%%,\"status\":*}
#	echo $host_name=$host_name
	name_formated=${host_name//\"/}

	if [[ $k8s_name =~ "offline" ]]
	then
		query_labels=`curl --request GET --url http://http://nodemanager.hulk.test.sankuai.com/nodemanager/api/node/$name_formated/labels`
		query_host=`curl --request GET --url http://nodemanager.hulk.test.sankuai.com/api/host/hardware/get?hostName=$name_formated`
	else
		query_labels=`curl --request GET --url http://nodemanager.hulk.vip.sankuai.com/nodemanager/api/node/$name_formated/labels`
		query_host=`curl --request GET --url http://nodemanager.hulk.vip.sankuai.com/api/host/hardware/get?hostName=$name_formated`
	fi
	if [[ $query_labels =~ "\"dedicated\":" ]]
	then
		dedicated_label=${query_labels#*\"dedicated\":}
		dedicated=${dedicated_label%,\"disktype\":*}
	else
		dedicated=
	fi
	if [[ $query_labels =~ "\"groupName\":" ]]
	then
		groupname_label=${query_labels#*\"groupName\":}
		groupname=${groupname_label%,\"*}
	else
		groupname=
	fi
	if [ -n "$dedicated"  -o  -n "$groupname" ]
	then
		echo $name_formated" $dedicated $groupname" >> $output_dedicated

		query_result=${query_result#*\"hostname\":}
		res_len=$res_len_cut
		res_len_cut=${#query_result}

		continue
	fi
	query_host=${query_host#*\"cpuNum\":}
	cpunum=${query_host%,\"memType\":*}
#	echo query_host=$query_host
#	echo cpunum=$cpunum
	echo $name_formated " " $cpunum >> $output_file

	query_result=${query_result#*\"hostname\":}
	res_len=$res_len_cut
	res_len_cut=${#query_result}
done

