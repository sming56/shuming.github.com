#!/usr/bin/bash
#gfile="./grub"
gfile="/etc/default/grub"

lscpu | grep AuthenticAMD
if [ $? -ne 0 ]; then
  echo " Not AMD machine. Exiting"
  exit 1
fi
sed 's/GRUB_DEFAULT\=2/GRUB_DEFAULT\=saved/g' -i $gfile
sed 's/GRUB_CMDLINE_LINUX\=\"crashkernel\=auto rhgb quiet cgwb_v1\"/GRUB_CMDLINE_LINUX\="processor.max_cstate\=8 intel_idle.max_cstate\=9 idle\=xx crashkernel\=auto rhgb quiet\"/g' -i $gfile

grub2-mkconfig -o /boot/grub2/grub.cfg
