#!/usr/bin/expect
set host_names [lindex $argv 0]
#give your username and password here
set id [lindex $argv 1]
set pass [lindex $argv 2]
#spawn sudo -iu sankuai
#spawn sudo -s
spawn rm -rf /opt/cores_saved/$host_names
#sleep 5s before rm command finsihed
sleep 5
spawn scp -r $id@$host_names:/tmp/crash_cores /opt/cores_saved/$host_names
expect {
"*(yes/no)?" {send "yes"}
"*password:" {send "$pass\r"}
}
interact
