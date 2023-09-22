#!/usr/bin/bash
max_loop=0
host_names=
#give your username and password here
pass=
user=
read -p "Entery you ID:" user
read -p "Entery you password:" pass

query_result=`curl --request GET --url http://kapiserver.hulk.vip.sankuai.com/api/app/instance?appkey="com.sankuai.meishi.eagle.gravityes"`
query_code=${query_result#*\"code\":}
query_code=${query_code%,\"message\":*}
if [ $query_code != 0 ]
then
   echo query_code = $query_code
   exit
fi
echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
#containerinfos=${query_result#*,\"hostName\":}
#cname=${containerinfos%%,\"ip\":*}
#echo "host:$cname found"
containerinfos2=$query_result
containerinfos1=$query_result
while [[ $containerinfos2 =~ "hostName" ]] 
do
   if [ $max_loop -gt 200 ]
   then
      break
   fi
   containerinfos2=${containerinfos2#*,\"hostName\":}
   containerinfos1=${containerinfos1#*,\"setName\":}
   cname=${containerinfos1%%,\"ip\":*}
   hostname=${containerinfos2%%,\"cpu\":*}
   echo "host:$hostname $cname found"
   hostname=`echo $hostname | awk -F"\"" '{print $2}'`
   host_osmodle=$(sshpass -p "$pass" ssh -t $user@$hostname -o StrictHostKeychecking=no uname -a)
#   echo $host_osmodle >> gravityes.text
   host_osmodle=`echo $host_osmodle | awk '{print $3}'`
   max_loop=$[max_loop+1]
   host_names=$host_names" "$cname
   echo $cname $hostname $host_osmodle  >> gravityes.text
done
echo "All hosts: $host_names"
