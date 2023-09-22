#!/usr/bin/bash
max_loop=0
host_names=
#give your username and password here
pass="Mish256!123"
user=
hosts_file="netopt_list.txt"

#read -p "Entery you password:" pass

for name in `cat $hosts_file`
do
   host=$name
   netopt_out=$(sshpass -p $pass ssh -t shuming02@$host -o StrictHostKeychecking=no << !
   sudo -iu sankuai
   sudo -s
   rm -f /home/sankuai/net_irq_optimize_07_18.sh
   rm -f /home/sankuai/irq_cpu_mapping.sh
   rm -f /home/sankuai/safe_restart_kubelet.sh
   rm -rf /var/hulk/hulk_irq_cores
   rm -rf /var/hulk/hulk_app_cores
   wget https://kernel.sankuai.com/tools/shuming_scripts/net_irq_optimize_07_18.sh
   'cp'  /home/sankuai/net_irq_optimize_07_18.sh /etc/rc.sankuai.d/rc99.net_optimize.sh
   /etc/rc.sankuai.d/rc99.net_optimize.sh
   wget https://kernel.sankuai.com/tools/shuming_scripts/irq_cpu_mapping.sh
   chmod a+x /home/sankuai/irq_cpu_mapping.sh
   /home/sankuai/irq_cpu_mapping.sh
   rm -f ./irq_cpu_mapping.sh
   wget https://kernel.sankuai.com/tools/shuming_scripts/get_app_cores_netopt.sh
   'cp' get_app_cores_netopt.sh /usr/bin/get_app_cores.sh
   rm ./get_app_cores_netopt.sh
   wget https://kernel.sankuai.com/tools/shuming_scripts/safe_restart_kubelet.sh
   chmod a+x /home/sankuai/safe_restart_kubelet.sh
   /home/sankuai/safe_restart_kubelet.sh
   rm ./safe_restart_kubelet.sh
!
)

   echo "------netirq_optimize.sh on $host with output $netopt_out-----------" >> netopt.log
done
