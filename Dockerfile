FROM ubuntu:16.04
RUN apt-get update &&  \
    apt-get -y install curl jq unzip bc

RUN mkdir /servers
RUN mkdir -p /java/9
RUN mkdir -p /java/8
RUN mkdir /stats

# get ngrinder 3.4.1

#
# Create a default webapp direectory and install ngrinder
#
RUN mkdir /webapps
RUN curl -L -o /webapps/sngrinder.war  https://github.com/naver/ngrinder/releases/download/ngrinder-3.4.1-20170131/ngrinder-controller-3.4.1.war

#
# Get latest build info from adoptopenjdk site
# Download binary and expand to have a standard vm oriented name
#

# Get OpenJDK with Hotspot

RUN  export RELEASE_NAME=`curl -s -H 'accept-version: 1.0.0' https://api.adoptopenjdk.net/openjdk9/releases/x64_linux | jq  -r '.release_name'` && \
     export BIN_LINK=`curl -s -H 'accept-version: 1.0.0' https://api.adoptopenjdk.net/openjdk9/releases/x64_linux | jq -r '.binaries[0].binary_link'` && \
     curl -L  -o openjdk9-hotspot-javabin.tar.gz  $BIN_LINK &&  \
     gunzip openjdk9-hotspot-javabin.tar.gz  && \
     tar -xf openjdk9-hotspot-javabin.tar && \
     mv $RELEASE_NAME  /java/9/hotspot && \
     rm openjdk9-hotspot-javabin.tar


# Get OpenJDK with OpenJ9

RUN  export RELEASE_NAME=`curl -s -H 'accept-version: 1.0.0' https://api.adoptopenjdk.net/openjdk9-openj9/releases/x64_linux | jq  -r '.release_name'` && \
     export BIN_LINK=`curl -s -H 'accept-version: 1.0.0' https://api.adoptopenjdk.net/openjdk9-openj9/releases/x64_linux | jq -r '.binaries[0].binary_link'` && \
     curl -L  -o openjdk9-openj9-javabin.tar.gz  $BIN_LINK &&  \
     gunzip openjdk9-openj9-javabin.tar.gz  && \
     tar -xf openjdk9-openj9-javabin.tar && \
     mv $RELEASE_NAME  /java/9/openj9 && \
     rm openjdk9-openj9-javabin.tar

# get tomcat 9.05
# and install in /servers/tomcat
# replace the tomcat webapps dir with a symlink to the root version

RUN  curl -L -o apache-tomcat-9.0.5.tar.gz  http://mirrors.ukfast.co.uk/sites/ftp.apache.org/tomcat/tomcat-9/v9.0.5/bin/apache-tomcat-9.0.5.tar.gz && \
     gunzip  apache-tomcat-9.0.5.tar.gz  && \
     mkdir -p /servers/tomcat && \
     tar -xf apache-tomcat-9.0.5.tar  -C /servers/tomcat --strip-components 1 && \
     rm apache-tomcat-9.0.5.tar


# get Open Liberty 17.0.0.4

RUN curl -L -o openliberty-17.0.0.4.zip  https://public.dhe.ibm.com/ibmdl/export/pub/software/openliberty/runtime/release/2017-12-06_1606/openliberty-17.0.0.4.zip

RUN unzip  -q openliberty-17.0.0.4.zip  && \
    rm openliberty-17.0.0.4.zip && \
    mv wlp  /servers/openliberty

#
# get jetty
#

RUN curl -L -o jetty.tar.gz  http://central.maven.org/maven2/org/eclipse/jetty/jetty-distribution/9.4.8.v20171121/jetty-distribution-9.4.8.v20171121.tar.gz && \
    gunzip  jetty.tar.gz && \
    mkdir /servers/jetty && \
    tar -xf jetty.tar -C /servers/jetty --strip-components 1  && \
    rm jetty.tar


# at this point we have 4 specific directories in /
#
# openjdk9-hotspot
# openjdk9-openj9
# openliberty-17.0.0.4
# apache-tomcat-9.0.5
#
# and the ngrinder war file:
#
# ngrinder-controller-3.4.1.war




# Get OpenJDK with OpenJ9
#RUN  curl   -vs -H 'accept-version: 1.0.0' https://api.adoptopenjdk.net/openjdk8/releases/x64_linux | jq -r '.[0].binaries[0].binary_link' 2>&1

RUN  export RELEASE_NAME=`curl -s -H 'accept-version: 1.0.0' https://api.adoptopenjdk.net/openjdk8/releases/x64_linux | jq  -r '.[0].release_name'` && \
     export BIN_LINK=`curl -s -H 'accept-version: 1.0.0' https://api.adoptopenjdk.net/openjdk8/releases/x64_linux | jq -r '.[0].binaries[0].binary_link'` && \
     echo $BIN_LINK && \
     curl -L  -o openjdk8-hotspot-javabin.tar.gz  $BIN_LINK &&  \
     gunzip openjdk8-hotspot-javabin.tar.gz  && \
     tar -xf openjdk8-hotspot-javabin.tar && \
     mv $RELEASE_NAME  /java/8/hotspot && \
     rm openjdk8-hotspot-javabin.tar


# Get OpenJDK with OpenJ9

RUN  export RELEASE_NAME=`curl -s -H 'accept-version: 1.0.0' https://api.adoptopenjdk.net/openjdk8-openj9/releases/x64_linux | jq  -r '.release_name'` && \
     export BIN_LINK=`curl -s -H 'accept-version: 1.0.0' https://api.adoptopenjdk.net/openjdk8-openj9/releases/x64_linux | jq -r '.binaries[0].binary_link'` && \
   echo $BIN_LINK && \
     curl -L  -o openjdk8-openj9-javabin.tar.gz  $BIN_LINK &&  \
     gunzip openjdk8-openj9-javabin.tar.gz  && \
     tar -xf openjdk8-openj9-javabin.tar && \
     mv $RELEASE_NAME  /java/8/openj9 && \
     rm openjdk8-openj9-javabin.tar


COPY entry.sh /
RUN chmod +x entry.sh
ENTRYPOINT ["/entry.sh"]

RUN mkdir /cache

# Get OpenJDK with Hotspot

# Tomcat should be in /apache-tomcat-9.0.5
# OpenJDK JDK9 with Hotspot in  /openjdk9-hotspot
# OpenJDK JDK9 with OpenJ9  in  /openjdk9-openJ9
# curl --unix-socket /var/run/docker.sock http://docker/images/json
# get self pid
# cat /proc/self/cgroup | head -n 1   | sed "s/.*docker\/\(.*\)/\1/"
#  curl --unix-socket /var/run/docker.sock http://docker/containers/a45a78e9420467ca0af0100a50047f6ad69406a9caae2635a2901dc04bd5c485/stats
