#!/usr/bin/bash
max_loop=0
host_names=
#give your username and password here
pass=
user=
#give your appkey here
appkey="com.sankuai.wpt.web.gaea"

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
while [[ $containerinfos =~ "hostName" ]] 
do
   if [ $max_loop -gt 207 ]
   then
      break
   fi
   containerinfos=${containerinfos#*,\"hostName\":}
   cname=${containerinfos%%,\"cpu\":*}
   echo "host:$cname found"
   max_loop=$[max_loop+1]
   host_names=$host_names" "$cname
done
for name in $host_names
do
   host=`echo $name | sed 's/\"//g'`   
   sshpass -p $pass ssh -t $user@$host -o StrictHostKeychecking=no << !
   sudo -iu sankuai
   sudo -s
   cd /tmp
   wget http://kernel.sankuai.com/tools/install_config_atop.sh
   chmod a+x /tmp/install_config_atop.sh
   /tmp/install_config_atop.sh
   exit
!
done
echo "All hosts installed: $host_names"
