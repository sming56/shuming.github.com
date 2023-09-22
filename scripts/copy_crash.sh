#!/usr/bin/bash

dirs=`ls -r /opt/crash`
latest_dir=`echo $dirs | awk '{print $1}'`
mkdir /tmp/crash_cores
cp -r /opt/crash/$latest_dir /tmp/crash_cores
chmod a+r -R /tmp/crash_cores
