
rpm -q mnic-init > /dev/null
if [ $? -ne 0 ]; then
    exit 0
fi

cat /proc/net/dev | grep ovs0 > /dev/null
if [ $? -ne 0 ]; then
    exit 0
fi

echo MNIC-hostname: `hostname`
