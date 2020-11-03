#!/bin/bash
master=`sudo docker ps |grep -c master`
worker=`sudo docker ps |grep -c worker`
criteo=`sudo docker ps |grep -c criteo`
online=1


for i in $criteo
do
if [ $i -eq $online ]
  then sudo docker kill criteo && echo "killing old criteo instance"
  else echo "criteo not running" | sudo docker rm criteo &> /dev/null
fi
done

for i in $master
do
if [ $i -eq $online ]
  then sudo docker kill master && echo "killing old master instance"
  else echo "master not running" | sudo docker rm master &> /dev/null
fi
done

for i in $worker
do
if [ $i -eq $online ]
  then sudo docker kill worker && echo "killing old worker instance"
  else echo "master not running" |  sudo docker rm worker &> /dev/null
fi
done
