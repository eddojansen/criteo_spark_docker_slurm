#!/bin/bash
##wait-worker.sh##
steptime=3
num_workers=`cat $MOUNT/conf/slaves|wc -l`
echo number of workers to be registered: $num_workers
for i in {1..100}
do
  sleep $steptime
  num_reg=`sudo docker logs master |grep -c "Registering worker"`
  if [ $num_reg -eq $num_workers ]
  then
     break
  fi
done
echo registered workers after $((i * steptime)) seconds: $num_reg
