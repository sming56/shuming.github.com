# wrtfile.sh file is required to execute this file
#!/bin/bash

for counter in {1..10000}
do
   docker run --name ming_c1 -d -it centos
   docker cp ./wrtfile.sh ming_c1:/
   docker exec -it ming_c1 bash /wrtfile.sh
   docker rm ming_c1 -f
done
