
#!/usr/bin/bash

if [ $# -ne 1 ]
then
      echo "The number of parameters is wrong"
      echo "Usage: ./script container_hostname"
      echo ".mt suffixed for container_hostname"
      exit 1
fi

targethname=$1

get_containerid_from_hostname()
{
  target_hostname=$1
  echo "target: $target_hostname"
  chname=""

  ids=`docker ps |grep -v pause | grep -v "prometheus-node" | awk '{print $1}'`
  for id in $ids; do
      if [[ $id == "CONTAINER" ]]; then
          echo "skiping $id"
          continue
      fi
      echo $id
      if echo $id | egrep -q '^[a-zA-Z0-9]+$' >/dev/null; then
          chname="`docker exec -it ${id} hostname`"
          chname=`echo $chname | sed 's/\r//g'|awk -F. '{print $1}'`
          echo $chname
          if [ "$chname"x == "$target_hostname"x ]; then
              #echo "The container ID of host ${chname} is $id"
              cid_found=$id
              break
          fi
      else
 echo ""
          #echo "$id is not container id"
      fi
  done
  if [[ "$cid_found"x == x ]]; then
      echo "no valid cid found for host: $target_hostname"
      exit 1
  fi
}

get_containerid_from_hostname $targethname
echo "the contain id of host $targethname is $cid_found"


pid=`docker inspect -f {{.State.Pid}} $cid_found`
cgrouppath=`cat /proc/$pid/cgroup | head -n 1 | awk -F ":" '{print $3}'`
cpupath="/sys/fs/cgroup/cpu$cgrouppath"
pidspath="/sys/fs/cgroup/pids$cgrouppath"
agentcpupath=$cpupath/agent_limit/cgroup.procs
agentpidspath=$pidspath/agent_limit/cgroup.procs
echo "cpupath=$cpupath"
echo "pidspath=$pidspath"
echo "agentcpupath=$agentcpupath"
echo "agentpidspath=$agentpidspath"


#--------------------
procs_to_beremoved=""
agentcpu_procs=`cat $agentcpupath | xargs`
for proc in $agentcpu_procs; do
 cmd="/proc/$proc/cmdline"
 #????
 echo `cat $cmd` | grep -Ev "container-agent|direwolf|falcon-agent"
 if [ $? -eq 0 ]; then
    procs_to_beremoved="$proc $procs_to_beremoved"
 else
    procs_keeping="$proc $procs_keeping"
 fi
done
echo "procs_to_beremoved=$procs_to_beremoved"
echo "procs_keeping=$procs_keeping"
for proc in $procs_keeping; do
 echo "proc to be saved: $proc"
 #echo $proc >> $agentcpupath
done
for proc in $procs_to_beremoved; do
 echo "proc to be remove: $proc"
 echo $proc >> $cpupath/cgroup.procs
done




#--------------------
procs_to_beremoved=""
agentpid_procs=`cat $agentpidspath | xargs`
for proc in $agentpid_procs; do
 cmd2="/proc/$proc/cmdline"
 #????
 echo `cat $cmd2` | grep -Ev "container-agent|direwolf|falcon-agent"
 if [ $? -eq 0 ]; then
    procs_to_beremoved="$proc $procs_to_beremoved"
 else
    procs_keeping="$proc $procs_keeping"
 fi
done

echo "procs_to_beremoved=$procs_to_beremoved"
echo "procs_keeping=$procs_keeping"
echo "#################################################"
for proc in $procs_to_beremoved; do
 echo "proc to be remove: $proc"
 echo $proc >> $pidspath/cgroup.procs
done
