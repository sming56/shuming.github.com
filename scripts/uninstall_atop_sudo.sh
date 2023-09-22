#! /bin/bash

sudo -iu sankuai
sudo -s

if [ -d "/opt/logs/atop" ];
then
	systemctl stop atop
	systemctl disable atop
fi
