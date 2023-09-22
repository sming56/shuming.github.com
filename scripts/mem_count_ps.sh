#!/bin/bash
sum=0
for mem in `ps aux |awk '{print $6}' |grep -v 'RSS'`
do
sum=$[$sum+$mem]
done
sum=$(echo "$sum / 1024 " | bc)
echo "The total memory is ${sum}M."
