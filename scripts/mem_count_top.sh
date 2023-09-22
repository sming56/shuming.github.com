#!/bin/bash
sum=0
for mem in `top -b -n 1  | sed -e '1,7d' | awk '{ print $6 }'`
do
   var=$(echo $mem | tr  -d '[0-9.]')
   num=$(echo $mem | tr -cd '[0-9.]')
   case $var in
       [Kk]*) sum=$(echo "$sum + $num * 1024" | bc) ;;              # 匹配k,K
       [Mm]*) sum=$(echo "$sum + $num * 1024 * 1024" | bc) ;;       # 匹配m,M
       [Gg]*) sum=$(echo "$sum + $num * 1024 * 1024 * 1024" | bc) ;;# 匹配g,G
       [Tt]*) sum=$(echo "$sum + $num * 1024 * 1024 * 1024 * 1024" | bc) ;;# 匹配g,G
           *) sum=$(echo "$sum + $num * 1024" | bc) ;; # 浮点型和整数通过bc来计算
   esac
done
sum=$(echo "$sum / 1024 /1024 " | bc)
echo "The total memory is ${sum}M."
