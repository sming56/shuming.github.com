if [ $# -ne 2 ]
then
     echo "Usage: contract.sh <token> <container list seperated by comma>"
# container name should not include ".mt"
     exit 1
fi
token=$1
containers=$2
contract_code=

function destroy_containers()
{
        containerhosts=$1
        appkey=$2
        for container_name in $containerhosts
        do
               contract_result=`curl --request POST \
 	       --url http://kapiserver.hulk.dev.sankuai.com/api/scalein \
 	       --header 'Content-Type: application/json' \
 	       --header 'auth-token: '$token'' \
 	       --data '{"appkey": "$appkey","idc": "yp", "env": "dev", "setNames": ["'$container_name'"]}'`
	       #contract_result='{"rescode":8258197,"errorInfo":"","code":200}'
	       contract_rescode=${contract_result#*\"rescode\":}
	       contract_rescode=${contract_rescode%,\"errorInfo\":*}
	       contract_code=${contract_result#*,\"code\":}
	       contract_code=${contract_code%\}*}
	       if [ $contract_code != 200 ]
	       then
		     echo contract container $container_name failed.
		     echo the contract result is: $contract_result
		     echo all the containers are: $containerhosts
                     echo  "try $appkey"
                     contract_result=`curl --request POST \
 	             --url http://kapiserver.hulk.dev.sankuai.com/api/scalein \
 	             --header 'Content-Type: application/json' \
 	             --header 'auth-token: '$token'' \
 	             --data '{"appkey": "$appkey","setNames": ["'$container_name'"]}'`
	             #contract_result='{"rescode":8258197,"errorInfo":"","code":200}'
	             contract_rescode=${contract_result#*\"rescode\":}
	             contract_rescode=${contract_rescode%,\"errorInfo\":*}
	             contract_code=${contract_result#*,\"code\":}
	             contract_code=${contract_code%\}*}
	             if [ $contract_code != 200 ]
                     then
                         echo  "try $appkey again failed"
                     fi
	       fi
	       contracted_num=$[ $contracted_num + 1 ]
	       echo "one time contract end"
	       echo container_name = $container_name
	       #echo contract_result = $contract_result
	       echo contract_rescode = $contract_rescode
	       echo contract_code = $contract_code
	       sleep 10
        done

}

function destroy_all_containers_onhost()
{
  ids=`docker ps |grep -v pause | grep -v "prometheus-node" | awk '{print $1}'`
  for id in $ids; do
        if [[ $id == "CONTAINER" ]]; then
            echo "skiping $id"
            continue
        fi
        echo "checking $id"
        if echo $id | egrep -q '^[a-zA-Z0-9]+$' >/dev/null; then
            chname="`docker exec -it ${id} hostname`"
            chname=`echo $chname | sed 's/\.mt\r//g'`
            echo "destroying container $chname"
            destroy_containers $chname "com.sankuai.hulk.autotest.ebs"
	    if [ $contract_code != 200 ]; then
                destroy_containers $chname "com.sankuai.inf.hulk.demo"
            fi
        else
            echo "$id is not container id"
        fi
  done
}

if [ $containers == "all" ]; then
   destroy_all_containers_onhost 
else
   destroy_containers $containers
fi
