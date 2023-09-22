#!/usr/bin/bash -x
# please check $hostname.crash file in current working directory for your crash stacks
if [ $# -ne 1 ]
then
     echo "Usage: command <hostname crashed>"
     exit 1
fi

host_name=$1

#give your username and password here
pass=
user=

read -p "Entery you ID:" user
read -p "Entery you password:" pass
sshpass -p $pass ssh -t $user@$host_name -o StrictHostKeychecking=no uname -a > /tmp/kernel_version
kernel_version=`cat /tmp/kernel_version | awk '{print $3}'`
if [[ $pass =~ '$' ]]
then
   escpass=${pass//\$/\\$}
elif [[ $pass =~ '&' ]]
then
   escpass=${pass//\&/\\&}
else
   escpass=$pass
fi

case $kernel_version in
   "4.18.0-80.mt20191225.323.el8_0.x86_64") 
      sshpass -p $pass ssh -t $user@xr-kernel-safety-msegmentation-test01 -o StrictHostKeychecking=no sudo -s /opt/cores_saved/get_cores.sh $host_name $user $escpass
      sshpass -p $pass ssh -t $user@xr-kernel-safety-msegmentation-test01 -o StrictHostKeychecking=no sudo -s cat /opt/cores_saved/bt.output.$host_name > ${host_name}.crash
      ;;
   "4.18.0-147.mt20200626.413.el8_1.x86_64")
      sshpass -p $pass ssh -t $user@gh-kernel-safety-msegmentation-test01 -o StrictHostKeychecking=no sudo -s /opt/cores_saved/get_cores.sh $host_name $user $escpass
      sshpass -p $pass ssh -t $user@gh-kernel-safety-msegmentation-test01 -o StrictHostKeychecking=no sudo -s cat /opt/cores_saved/bt.output.$host_name > ${host_name}.crash
      ;;
   "3.10.0-862.mt20190308.130.el7.x86_64")
      sshpass -p $pass ssh -t $user@gh-kernel-safety-msegmentation-test02 -o StrictHostKeychecking=no sudo -s /opt/cores_saved/get_cores.sh $host_name $user "$escpass"
      sshpass -p $pass ssh -t $user@gh-kernel-safety-msegmentation-test02 -o StrictHostKeychecking=no sudo -s cat /opt/cores_saved/bt.output.$host_name > ${host_name}.crash
      ;;
   *) echo "Sorry, We don't support $kernel_version"
      ;;
esac

rm -f /tmp/kernel_version
