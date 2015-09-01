FROM debian:jessie
FROM java:7
MAINTAINER hwang <hwang@transcendinsight.com>

USER root

RUN apt-get update && apt-get install -y openssh-server openssh-client rsync --no-install-recommends && rm -rf /var/lib/apt/lists/*

# Hadoop
RUN wget http://mirror.tcpdiag.net/apache/hadoop/common/hadoop-2.6.0/hadoop-2.6.0.tar.gz
RUN mv hadoop-2.6.0.tar.gz /usr/local/
RUN cd /usr/local && tar -zxf hadoop-2.6.0.tar.gz && ln -s ./hadoop-2.6.0 hadoop && rm hadoop-2.6.0.tar.gz

# Hive
RUN wget https://archive.apache.org/dist/hive/hive-0.13.1/apache-hive-0.13.1-bin.tar.gz
RUN mv apache-hive-0.13.1-bin.tar.gz /usr/local
RUN cd /usr/local && tar -xzf apache-hive-0.13.1-bin.tar.gz && ln -s ./apache-hive-0.13.1-bin hive && rm apache-hive-0.13.1-bin.tar.gz

# Spark
RUN wget http://d3kbcqa49mib13.cloudfront.net/spark-1.3.1-bin-hadoop2.6.tgz
RUN mv spark-1.3.1-bin-hadoop2.6.tgz /usr/local/
RUN cd /usr/local && tar -xzf spark-1.3.1-bin-hadoop2.6.tgz && ln -s ./spark-1.3.1-bin-hadoop2.6 spark && rm spark-1.3.1-bin-hadoop2.6.tgz

# Spark-jobserver
RUN cd /root && git clone https://github.com/huaxiawang/spark-jobserver.git

# passwordless ssh
# RUN ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
# RUN ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

# Java
ENV JAVA_HOME /usr/lib/jvm/java-7-openjdk-amd64

# Hadoop ENV
ENV HADOOP_PREFIX /usr/local/hadoop
ENV HADOOP_COMMON_HOME /usr/local/hadoop
ENV HADOOP_HDFS_HOME /usr/local/hadoop
ENV HADOOP_MAPRED_HOME /usr/local/hadoop
ENV HADOOP_YARN_HOME /usr/local/hadoop
ENV HADOOP_CONF_DIR /usr/local/hadoop/etc/hadoop
ENV YARN_CONF_DIR $HADOOP_PREFIX/etc/hadoop

# Hive ENV
ENV HIVE_HOME=/usr/local/hive
ENV HIVE_CONF_DIR=$HIVE_HOME/conf

# Spark ENV
ENV SPARK_HOME=/usr/local/spark
ENV SPARK_CONF_DIR=$SPARK_HOME/conf

# Spark-jobserver ENV
ENV SCALA_VERSION 2.10.4
ENV SBT_VERSION 0.13.7

# Install sbt
RUN \
  wget -O sbt-$SBT_VERSION.deb https://dl.bintray.com/sbt/debian/sbt-$SBT_VERSION.deb && \
  dpkg -i sbt-$SBT_VERSION.deb && \
  rm sbt-$SBT_VERSION.deb && \
  apt-get update && \
  apt-get install sbt

RUN cd /root/spark-jobserver && git checkout docker && \
  bin/server_package.sh docker && mkdir /root/jobServer && \
  cp /tmp/job-server/job-server.tar.gz /root/jobServer && \
  cd /root/jobServer && tar -zxvf job-server.tar.gz

# Hadoop Conf
ADD core-site.xml.template $HADOOP_CONF_DIR/
RUN sed s/HOSTNAME/localhost/ /usr/local/hadoop/etc/hadoop/core-site.xml.template > /usr/local/hadoop/etc/hadoop/core-site.xml
ADD hdfs-site.xml $HADOOP_CONF_DIR/
ADD mapred-site.xml $HADOOP_CONF_DIR/
ADD yarn-site.xml $HADOOP_CONF_DIR/
ADD slaves $HADOOP_CONF_DIR/
ADD hadoop-env.sh $HADOOP_CONF_DIR/
RUN chmod 700 $HADOOP_CONF_DIR/hadoop-env.sh
RUN chmod +x $HADOOP_CONF_DIR/*-env.sh
RUN mkdir /var/hadoop && mkdir /var/tmp/pid

# Hive Conf
ADD mysql-connector-java.jar $HIVE_HOME/lib/
ADD hive-default.xml $HIVE_CONF_DIR/
ADD hive-site.xml $HIVE_CONF_DIR/
ADD hive-env.sh $HIVE_CONF_DIR/

# Spark Conf
ADD *.jar $SPARK_HOME/lib/
ADD spark-env.sh $SPARK_CONF_DIR/
ADD spark-defaults.conf $SPARK_CONF_DIR/
ADD slaves $SPARK_CONF_DIR/
ADD hive-site.xml $SPARK_CONF_DIR/

# Spark-Jobservr Conf
# Install Scala
RUN \
  cd /root && \
  wget -O scala-$SCALA_VERSION.tgz http://downloads.typesafe.com/scala/$SCALA_VERSION/scala-$SCALA_VERSION.tgz && \
  tar -xzf scala-$SCALA_VERSION.tgz && \
  rm scala-$SCALA_VERSION.tgz && \
  echo >> /root/.bashrc && \
  echo 'export PATH=~/scala-$SCALA_VERSION/bin:$PATH' >> /root/.bashrc

ENV CLASSPATH=$CLASSPATH:$HIVE_HOME/lib/mysql-connector-java.jar
ENV PATH=$PATH:$HADOOP_PREFIX/bin:$HIVE_HOME/bin:$SPARK_HOME/bin

RUN $HADOOP_PREFIX/bin/hdfs namenode -format

ADD ssh_config /root/.ssh/config
RUN chown root:root /root/.ssh/config
RUN chmod 600 /root/.ssh/config

RUN sed  -i "/^[^#]*UsePAM/ s/.*/#&/"  /etc/ssh/sshd_config
RUN echo "UsePAM no" >> /etc/ssh/sshd_config
RUN echo "Port 2122" >> /etc/ssh/sshd_config

RUN service ssh start && $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh && $HADOOP_PREFIX/sbin/start-dfs.sh && $HADOOP_PREFIX/bin/hdfs dfs -mkdir -p /user/root/log && $HADOOP_PREFIX/bin/hdfs dfs -mkdir /tmp && $HADOOP_PREFIX/bin/hdfs dfs -mkdir -p /user/hive/warehouse && $HADOOP_PREFIX/bin/hdfs dfs -chmod g+w /tmp && $HADOOP_PREFIX/bin/hdfs dfs -chmod g+w /user/hive/warehouse

# SSH
EXPOSE 22

# HDFS
# dfs.http.address
EXPOSE 50070

# fs.default.name
EXPOSE 9000

# dfs.datanode.http.address
EXPOSE 50075

# dfs.datanode.address
EXPOSE 50010

# dfs.datanode.ipc.address
EXPOSE 50020

# dfs.secondary.http.address
EXPOSE 50090

#YARN
# yarn.resourcemanager.scheduler.address
EXPOSE 8030

# yarn.resourcemanager.resource-tracker.address
EXPOSE 8031

# yarn.resourcemanager.address
EXPOSE 8032

# yarn.resourcemanager.admin.address
EXPOSE 8033

# yarn.nodemanager.localizer.address
EXPOSE 8040

# yarn.nodemanager.webapp.address
EXPOSE 8042

# yarn.resourcemanager.webapp.address
EXPOSE 8088

#HIVE
EXPOSE 10000 9083

#SPARK
EXPOSE 6066 7077 8080 8081

#SPARK JOBSERVER
EXPOSE 8090

ADD boot-platform.sh /
RUN chown root:root /boot-platform.sh
RUN chmod 700 /boot-platform.sh

CMD ["/boot-platform.sh", "-d"]