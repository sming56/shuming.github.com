#! /bin/bash

if [ -d "/opt/logs/atop" ];
then
	systemctl stop atop
	systemctl disable atop
fi
