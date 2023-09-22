#! /bin/bash

if [ -d "/opt/logs/atop" ];
then
	systemctl enable atop
	systemctl start atop
fi
