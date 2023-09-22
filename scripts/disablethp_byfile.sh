#!/usr/bin/bash
max_loop=0
host_names=
if [ $# -ne 1 ]
then
	echo "The number of parameters is wrong"
	echo "Usage: ./COMMAND file_name"
 	exit 1
fi

container_names=`cat $1`

#give your username and password here
pass=
user=
#give your appkey here

read -p "Entery you ID:" user
read -p "Entery you password:" pass

for cname in $container_names
do
	query_result=`curl --request GET --url http://kapiserver.hulk.vip.sankuai.com/api/app/instance?set_name=$cname&detail=0`
	query_code=${query_result#*\"code\":}
	query_code=${query_code%,\"message\":*}
	if [ $query_code != 0 ]
	then
		echo query_code = $query_code
		echo "container $cname querying error"
		continue
	fi
	echo "Start to disable THP for $cname"
	query_hostname=${query_result#*\"hostName\":}
	query_hostname=${query_hostname%,\"cpu\":*}
	echo "hostname=$query_hostname"
	host=`echo $query_hostname | sed 's/\"//g' | awk -F ',' '{print $1}'`
	current_defrag=$(sshpass -p $pass ssh -t $user@$host -o StrictHostKeychecking=no cat /sys/kernel/mm/transparent_hugepage/defrag)
	current_thp=$(sshpass -p $pass ssh -t $user@$host -o StrictHostKeychecking=no cat /sys/kernel/mm/transparent_hugepage/enabled)
	echo "current defrag: $current_defrag"
	echo "current thp: $current_thp"
	sshpass -p $pass ssh -t $user@$host -o StrictHostKeychecking=no << !
	sudo -iu sankuai
	sudo -s
	echo never > /sys/kernel/mm/transparent_hugepage/defrag
!

	sshpass -p $pass ssh -t $user@$host -o StrictHostKeychecking=no << !
	sudo -iu sankuai
	sudo -s
	echo never > /sys/kernel/mm/transparent_hugepage/enabled
!
done
