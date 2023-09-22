#This file is paired with panic.sh
#!/usr/bin/bash

touch junk.txt

for i in {1..100000}
do
   echo "I am a testing dog" >> junk.txt
done
