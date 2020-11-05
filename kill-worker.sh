#!/bin/bash
worker=`sudo docker ps |grep -c worker`
online=1

for i in $worker
do
if [ $i -eq $online ]
  then sudo docker kill worker && echo "killing old worker instance"
  else echo "master not running" |  sudo docker rm worker &> /dev/null
fi
done
