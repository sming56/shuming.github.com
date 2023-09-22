#!/usr/bin/bash
max_loop=0
host_names=
#give your username and password here
pass=
user=
hosts_file="hosts_swap.txt"
read -p "Entery you ID:" user
read -p "Entery you password:" pass
TMPEXPECT=expectscript.$$
cat <<EOT > $TMPEXPECT
#!/usr/bin/expect
if {[llength \$argv] != 3} {
   puts "usage: \$argv0 username password host"
   exit 1
}
set username  [lindex \$argv 0] 
set password  [lindex \$argv 1] 
set host      [lindex \$argv 2]

set timeout 60 

spawn /usr/bin/ssh \$username@\$host

expect {
    "assword: " {
        send "\$password\n"
        expect { 
            "expecting." { }
            "try again." { exit 1 }
            timeout      { exit 1 }
        } 
    }
    "(yes/no)? " { 
        send "yes\n" 
        expect {
            "assword: " {
                send "\$password\n"
                expect { 
                    "expecting." { }
                    "try again." { exit 1 }
                    timeout      { exit 1 }
                } 
            }
        }
    }
}
uname -r
exit 0
EOT
chmod 755 $TMPEXPECT

for cname in `cat $hosts_file`
do
	if [ $max_loop -gt 2 ]
	then
		break
	fi
	echo container: $cname
	containerinfo=`curl --request GET --url http://kapiserver.hulk.vip.sankuai.com/api/app/instance?set_name=$cname&detail=0`
	hname=${containerinfo#*,\"hostName\":}
	hostname=${hname%%,\"cpu\":*}
	echo host: $hostname
        hostname=`echo $hostname | awk -F"\"" '{print $2}'`
	echo host: $hostname
        echo pass: $pass
#        ./$TMPEXPECT $user $pass $hostname
	host_kerver=$(sshpass -p "$pass" ssh -t $user@$hostname -o StrictHostKeychecking=no uname -r)
        
        echo kernel_version: $host_kerver
        max_loop=$[max_loop+1]
done
#rm $TMPEXPECT
