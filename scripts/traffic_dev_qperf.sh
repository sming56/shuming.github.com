#!/bin/bash
#please use ssh-keygen to generate the public keys in current host
#then cop the public key to remote server you want to ssh without password from current host
# step 1 login shell in current server and generate the ras key for current login user
# ssh-keygen 
# step 2 copy the public key to the remote host to be accessed without password
# ssh-copy-id -i ~/.ssh/id_rsa.pub user@remote_host
# step 3 try to login the remote
# ssh -i 
#also please make sure ssh-keygen to generate the rsa key without password

if [ $# -ne 5 ]
then
	echo "The number of parameters is wrong"
	echo "Usage: ./traffic_test.sh token container_num interval hostname1/IP1 hostname2/IP2"
 	exit 1
fi

token=$1
container_num=$2
interval=$3
host1=$4
host2=$5
container_host=
container_ip=
container_hosts1=
container_hosts2=
container_ip1=
container_ip2=
actual_num=0

if [ $container_num -gt 20 ]
then
       echo "container numer exceed 20 limit"
       exit 1
fi


function get_containerid_from_hostname()
{
    target_hostname=$1
    echo "target: $target_hostname"
    chname=""
    main_host=$2
    current_host=`hostname`
    result=$(echo ${current_host}  | grep "${main_host}")

    if [[ $result == "" ]]
    then

        ids=`ssh -i /home/-i /home/shuming02/.ssh/id_rsa shuming02/.ssh/id_rsa -t shuming02@$main_host sudo -iu sankuai sudo -s docker ps |grep -v pause | grep -v "prometheus-node" | awk '{print $1}'`
    else
        ids=`sudo -iu sankuai sudo -s docker ps |grep -v pause | grep -v "prometheus-node" | awk '{print $1}'`
    fi
    for id in $ids; do
        if [[ $id == "CONTAINER" ]]; then
            echo "skiping $id"
            continue
        fi
        echo $id
        if echo $id | egrep -q '^[a-zA-Z0-9]+$' >/dev/null; then
    	    if [[ $result == "" ]]
            then
                chname="`ssh -i /home/shuming02/.ssh/id_rsa -t shuming02@$main_host sudo -iu sankuai sudo -s docker exec -it ${id} hostname`"
                chname=`echo $chname | sed 's/\r//g'`
            else
                chname="`sudo -iu sankuai sudo -s docker exec -it ${id} hostname`"
                chname=`echo $chname | sed 's/\r//g'`
            fi
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
		info_string=${query_result#*\"setsInfo\":\[\{\"name\":\"}
		container_host=${info_string%\",\"podName\":*}
		info_string=${query_result#*,\"ip\":\"}
		container_ip=${info_string%\",\"ipv6\":*}
		query_count=$[ $query_count - 1 ]
	
		echo query_code = $query_code
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


counter=$container_num
current_host=`hostname`

while [ $counter -gt 0 ]
do
        # start one container on host1
        create_one $host1
        if [ $? != 0 ]
        then
               echo "$i: create_one() on $host1 failed"
               break;
        fi
        sleep 10
        host_c1=$container_host
        host_c1_ip=$container_ip

        #start one container for host2
        create_one $host2
        if [ $? != 0 ]
        then
               echo "$i: create_one() on $host2 failed"
               destroy_containers $host_c1
               break;
        fi
        sleep 10
        host_c2=$container_host
        host_c2_ip=$container_ip

        #install qperf to the new created containers
        get_containerid_from_hostname $host_c1 $host1
        if [ $? != 0 ]
        then
               echo "Can not find the id for host:$host_c1"
               destroy_containers $host_c1
               destroy_containers $host_c2
               break;
        fi
        cid_found1=$cid_found
        echo "host1 id is $cid_found"
        result=$(echo ${current_host}  | grep "${host1}")
        if [[ $result == "" ]]
        then
            ssh -i /home/shuming02/.ssh/id_rsa -t shuming02@$host1 "sudo -iu sankuai sudo -s  docker exec -it $cid_found /usr/bin/yum -y install qperf"
        else
            sudo -iu sankuai sudo -s  docker exec -it $cid_found /usr/bin/yum -y install qperf
        fi

        
	#install qperf to the new created containers
        get_containerid_from_hostname $host_c2 $host2
        if [ $? != 0 ]
        then
               echo "Can not find the id for host:$host_c2"
               destroy_containers $host_c1
               destroy_containers $host_c2
               break;
        fi
        cid_found2=$cid_found
        echo "host2 id is $cid_found"
        result=$(echo ${current_host}  | grep "${host2}")
        if [[ $result == "" ]]
        then
            ssh -i /home/shuming02/.ssh/id_rsa -t shuming02@$host2 "sudo -iu sankuai sudo -s  docker exec -it $cid_found /usr/bin/yum -y install qperf"
        else
            sudo -iu sankuai sudo -s  docker exec -it $cid_found /usr/bin/yum -y install qperf
        fi

        actual_num=`expr $actual_num + 1`
	container_hosts1="$container_hosts1 $host_c1"
	container_hosts2="$container_hosts2 $host_c2"
	container_ips1="$container_ips1 $host_c1_ip"
	container_ips2="$container_ips2 $host_c2_ip"
	container_ids1="$container_ids1 $cid_found1"
	container_ids2="$container_ids2 $cid_found2"
	counter=$[ $counter - 1 ]
done
ids1_next=$container_ids1
ids2_next=$container_ids2
for ip1 in $container_ips1
do
        ids2_next=${ids2_next#*\ }
        ids1_next=${ids1_next#*\ }
        id1=${ids1_next%%\ *}
        id2=${ids2_next%%\ *}
        if [ "$id1"x == "x" ]
        then
               id1=$ids1_next
        fi
        if [ "$id2"x == "x" ]
        then
               id2=$ids2_next
        fi
        echo id2=$id2
        echo id1=$id1
        echo container1=$ip1
        result=$(echo ${current_host}  | grep "${host1}")

        if [[ $result == "" ]]
        then
            ssh -i /home/shuming02/.ssh/id_rsa -t shuming02@$host1  sudo -iu sankuai  sudo -s  docker exec -itd $id1 nohup qperf
        else
            sudo -iu sankuai  sudo -s  docker exec -itd $id1 nohup qperf
        fi
        #sleep 1 seconds for qperf server to start
        sleep 1
        result=$(echo ${current_host}  | grep "${host2}")
        if [[ $result == "" ]]
        then
            ssh -i /home/shuming02/.ssh/id_rsa -t shuming02@$host2 sudo -iu sankuai sudo -s  docker exec -itd $id2 nohup qperf $ip1 -vvu -t $interval tcp_lat conf
        else
            sudo -iu sankuai sudo -s  docker exec -itd $id2 nohup qperf $ip1 -vvu -t $interval tcp_lat conf
        fi
done

#sleep a while for qperf to exit
sleep `expr $interval + 30`
#collect the output from qperf server
echo "collect qperf output from $actual_num servers"
echo container_hosts1=$container_hosts1
echo container_hosts2=$container_hosts2
touch all_outputs.txt
for id2 in $container_ids2
do
        echo collecting stats id=$id2
        result=$(echo ${current_host}  | grep "${host2}")
        if [[ $result == "" ]]
        then
            ssh  -i /home/shuming02/.ssh/id_rsa -t shuming02@$host2 sudo -iu sankuai sudo -s docker exec -it $id2 cat /nohup.out > tmp_outputs.txt
        else
            sudo -iu sankuai sudo -s docker exec -it $id2 cat /nohup.out > tmp_outputs.txt
        fi
        cat tmp_outputs.txt >> all_outputs.txt
done

#destroy_containers "$container_hosts1"
sleep 5
#destroy_containers "$container_hosts2"
