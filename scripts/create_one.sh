#!/bin/bash

if [ $# -ne 2 ]
then
	echo "The number of parameters is wrong"
	echo "Usage: ./traffic_test.sh token hostname1/IP1"
 	exit 1
fi

token=$1
host1=$2

function get_containerid_from_hostname()
{
    target_hostname=$1
    echo "target: $target_hostname"
    chname=""
    main_host=$2

    ids=`ssh -t shuming02@$main_host sudo -iu sankuai sudo -s docker ps |grep -v pause | grep -v "prometheus-node" | awk '{print $1}'`
    for id in $ids; do
        if [[ $id == "CONTAINER" ]]; then
            echo "skiping $id"
            continue
        fi
        echo $id
        if echo $id | egrep -q '^[a-zA-Z0-9]+$' >/dev/null; then
            chname="`ssh -t shuming02@$main_host sudo -iu sankuai sudo -s docker exec -it ${id} hostname`"
            chname=`echo $chname | sed 's/\r//g'`
            echo $chname
            if [ "$chname"x == "$target_hostname"x ]; then
                echo "The container ID of host ${chname} is $id"
                cid_found=$id
                break
            fi
            if [ $chname == $target_hostname.mt ]; then
                echo "The container ID of host ${chname} is $id"
                cid_found=$id
                break
            fi
        else
            echo "$id is not container id"
            return 1
        fi
    done
    if [[ "$cid_found"x == x ]]; then
        echo "no valid cid found for host: $target_hostname"
        return 1
    fi
    return 0
}
function create_one()
{
        echo "create one container on $1"
        idc_name=$1
        idc_name=${idc_name:0:2}

        expand_result=`curl --request POST \
	--url http://kapiserver.hulk.dev.sankuai.com/api/scaleout \
	--header 'Content-Type: application/json' \
	--header 'auth-token: '$token'' \
	--data '{"ignoreResourceCheck":"test", "skipLicenseCheck":true, "appkey": "com.sankuai.hulk.offlinedemo", "idc": "'$idc_name'", "env": "dev","num": 1,"cpu": 4,"mem": 4096,"hd": 200,"clusterType": "hulk_kernal_qa"  ,"additional":{"requireAffinities":[{"key":"kubernetes.io/hostname","inValues":["'$1.mt'"],"operator":"IN"}] }}'`
	#expand_result='{"rescode":8258135,"errorInfo":"","code":200}'
	expand_rescode=${expand_result#*\"rescode\":}
	expand_rescode=${expand_rescode%,\"errorInfo\":*}
	expand_code=${expand_result#*,\"code\":}
	expand_code=${expand_code%\}*}
	if [ $expand_code != 200 ]
	then
		echo the first $i container expand failed.
		echo the expand result is: $expand_result
                return 1
	fi
	expanded_num=$[ $expanded_num + 1 ]
	sleep 5
	query_count=100
	while [ $query_count -gt 0 ]
	do
		query_result=`curl --request GET \
	 	--url http://kapiserver.hulk.dev.sankuai.com/api/scaleout/$expand_rescode \
	 	--header 'Accept: application/json,*/*' \
	 	--header 'Content-Type: application/json' \
	 	--header 'auth-token: '$token''`
		#query_result='{"code":0,"status":"completed","errorInfo":"","setsInfo":[{"name":"set-zf-hulk-hulk-demo-test08","podName":"inf-hulk-demo-test-1d55d856b068cbaf341c98f31326b06f-n1ckr","ip":"10.189.100.77","host":"zf-hulk-k8s-ep-test02","hostIp":"10.189.64.2","router":null,"uuid":"8f853185-689d-4051-844e-3bed7f515c7b","cpu":4,"mem":4096,"disk":200,"idc":"zf","image":"registry-hulk.sankuai.com/sankuai/centos:offline_java_191015_centos6"}],"startTimestamp":1573645999864,"endTimestamp":1573646006937}'
		query_code=${query_result#*\{\"code\":}
		query_code=${query_code%,\"status\":*}
		container_host=${query_result#*\"setsInfo\":\[\{\"name\":\"}
		container_host=${container_host%\",\"podName\":*}
		query_count=$[ $query_count - 1 ]
	
		echo query_code = $query_code
		echo expand_rescode = $expand_rescode
		echo expand_code = $expand_code
		if [ $query_code != 0 ]
		then
			sleep 2
			continue
		else
			break
		fi
	done
	if [ $query_code != 0 ]
 	then
		echo the first $i query failed.
		echo the query result is: $query_result
		return 1
	fi
	query_num=$[ $query_num + 1 ]
	echo "one time expand and query end"
	#echo expand_result  = $expand_result
	echo expand_rescode = $expand_rescode
	echo expand_code = $expand_code
	#echo query_result = $query_result
	echo container_host = $container_host
        return 0

}

function destroy_containers()
{
        containerhosts=$1
        for container_name in $containerhosts
        do
               contract_result=`curl --request POST \
 	       --url http://kapiserver.hulk.dev.sankuai.com/api/scalein \
 	       --header 'Content-Type: application/json' \
 	       --header 'auth-token: '$token'' \
 	       --data '{"appkey": "com.sankuai.hulk.offlinedemo","setNames": ["'$container_name'"]}'`
	       #contract_result='{"rescode":8258197,"errorInfo":"","code":200}'
	       contract_rescode=${contract_result#*\"rescode\":}
	       contract_rescode=${contract_rescode%,\"errorInfo\":*}
	       contract_code=${contract_result#*,\"code\":}
	       contract_code=${contract_code%\}*}
	       if [ $contract_code != 200 ]
	       then
		     echo contract container $container_name failed.
		     echo the contract result is: $contract_result
		     echo all the containers are: $container_hosts
	       fi
	       contracted_num=$[ $contracted_num + 1 ]
	       echo "one time contract end"
	       echo container_name = $container_name
	       #echo contract_result = $contract_result
	       echo contract_rescode = $contract_rescode
	       echo contract_code = $contract_code
	       sleep 5
        done

}


# start one container on host1
create_one $host1
if [ $? != 0 ]
then
   echo "$i: create_one() on $host1 failed"
fi
sleep 10
host_c1=$container_host

#destroy_containers "$host_c1"
