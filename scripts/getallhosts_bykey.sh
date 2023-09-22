#!/usr/bin/bash
max_loop=0
host_names=

query_result=`curl --request GET --url http://kapiserver.hulk.vip.sankuai.com/api/app/instance?appkey="credit-textclassifybydl-service"`
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
while [[ $containerinfos =~ "hostName" ]] 
do
   if [ $max_loop -gt 89 ]
   then
      break
   fi
   containerinfos=${containerinfos#*,\"hostName\":}
   cname=${containerinfos%%,\"cpu\":*}
   echo "host:$cname found"
   max_loop=$[max_loop+1]
   host_names=$host_names" "$cname
done
echo "All hosts: $host_names"
#for name in $host_names
#do
#   host=`echo $name | sed 's/\"//g'`   
#   ssh -t shuming02@$host sudo -iu sankuai sudo -s < "install_config_atop.sh"
#done
