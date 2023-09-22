#!/usr/bin/bash
max_loop=0
host_names=
#give your username and password here
pass=
user=
#give your appkey here
appkey="com.sankuai.waimai.d.searchrecallserver"
#appkey="com.sankuai.waimai.d.searchesdx"

read -p "Entery you ID:" user
read -p "Entery you password:" pass

query_result=`curl --request GET --url http://kapiserver.hulk.vip.sankuai.com/api/app/instance?appkey=$appkey`
query_code=${query_result#*\"code\":}
query_code=${query_code%,\"message\":*}
if [ $query_code != 0 ]
then
   echo query_code = $query_code
   exit
fi
echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
containerinfos=${query_result#*,\"hostName\":}
cname=${containerinfos%%,\"cpu\":*}
echo "host:$cname found"
containerinfos2=${query_result#*,\"setName\":}
container_name=${containerinfos2%%, \"ip\":*}

while [[ $containerinfos =~ "hostName" ]] 
do
   if [ $max_loop -gt 500 ]
   then
      break
   fi
   containerinfos=${containerinfos#*,\"hostName\":}
   cname=${containerinfos%%,\"cpu\":*}
   containerinfos2=${containerinfos2#*,\"setName\":}
   container_name=${containerinfos2%%,\"ip\":*}
#   echo "host:$cname found"
#   echo "container:$container_name found"
   max_loop=$[max_loop+1]
   host_names=$host_names" "${cname},${container_name}
done
for name in $host_names
do
   host=`echo $name | sed 's/\"//g' | awk -F ',' '{print $1}'`
   cpu_modelname=$(sshpass -p $pass ssh -t $user@$host -o StrictHostKeychecking=no lscpu | grep "Model name" | awk -F ":" '{print $2}')
   echo $name $cpu_modelname >> cpu_lists.txt
done
#echo "All hosts installed: $host_names"
