#!/bin/bash -e
: ${HADOOP_PREFIX:=/usr/local/hadoop}
: ${HIVE_HOME:=/usr/local/hive}
: ${SPARK_HOME:=/usr/local/spark}
: ${SPARK_JOBSERVER:=/root/jobServer}
$HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
$HIVE_HOME/conf/hive-env.sh
$SPARK_HOME/conf/spark-env.sh

sed s/HOSTNAME/$HOSTNAME/ /usr/local/hadoop/etc/hadoop/core-site.xml.template > /usr/local/hadoop/etc/hadoop/core-site.xml

service ssh start

cd $HADOOP_PREFIX
sbin/start-dfs.sh
sbin/start-yarn.sh

cd $SPARK_HOME
sbin/start-master.sh
sbin/start-slaves.sh

cd $SPARK_JOBSERVER
./server_start.sh

cd $HIVE_HOME
bin/hiveserver2

if [[ $1 == "-d" ]]; then
  while true; do sleep 1000; done
fi

if [[ $1 == "-bash" ]]; then
  /bin/bash
fi