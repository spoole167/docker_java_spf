#!/bin/bash
#
# Simple script to setup and execute the choosen app server with openjdk varient
#
# Expected input is of the form
#
# command.sh  [ openj9 | hotspot ]  [tomcat | openliberty ]
#
#
startup_time=0
servers=(jetty openliberty tomcat)
java_runtimes=(openj9 hotspot)
java_runtime_versions=(8 9)
run_number=""
modes=(container standard shared)
mode="container"


gather_stats() {
  container_id=$(cat /proc/self/cgroup | head -n 1   | sed "s/.*docker\/\(.*\)/\1/")
  curl -L -s --unix-socket /var/run/docker.sock "http://docker/containers/$container_id/stats" > /stats/data &
  stats_tool=$!
}

pre_call() {

  case $java_runtime in
    "hotspot")
      if [ "$mode" == "shared" ] && [  "$run_number" == "1" ]
      then
        rebuild_command="${JAVA_HOME}/bin/java -Xshare:dump  -XX:+UnlockDiagnosticVMOptions  -XX:SharedArchiveFile=${jcache_file}"
        data=$( { time $rebuild_command ; }  2>&1  | grep 'real' | sed "s/.*real\(.*\)m\(.*\)s/\1 \2/")  # real 0m0.336s
        timings=($data)
        cmd="scale=0 ; ( ${timings[0]}*60 +${timings[1]} )* 1000 "
        setup_time=$( echo $cmd  | bc )
        setup_time=${setup_time%.*}

      fi
    ;;
  esac

}


config_hotspot() {

  export JAVA_HOME="/java/$java_runtime_version/hotspot"
  javaopts=""

  case $mode in

    "container")

    ;;
    "standard")
      # do nothing - ie set no special configs
    ;;
    "shared")

      jcache="/cache/java/hotspot/${java_runtime_version}"
      $(mkdir -p ${jcache})
      jcache_file="${jcache}/${server_type}.jsa"
      javaopts="-Xshare:on -XX:+UnlockDiagnosticVMOptions -XX:SharedArchiveFile=${jcache_file}"

  ;;
  esac
  export JAVA_OPTIONS="$javaopts"
  export JAVA_OPTS="$javaopts"
  export JVM_ARGS="$javaopts"
}

config_openj9() {

  export JAVA_HOME="/java/$java_runtime_version/openj9"
  javaopts=""

  case $mode in

    "container")
      javaopts="-Xquickstart"
    ;;
    "standard")
      # do nothing - ie set no special configs
    ;;
    "shared")

      jcache="/cache/java/openj9/$java_runtime_version"
      mkdir -p $jcache
      javaopts="-Xquickstart -Xscmx1G -Xshareclasses:cacheDir=$jcache,name=$server_type,persistent "

  ;;
  esac

  export JAVA_OPTIONS="$javaopts"
  export JAVA_OPTS="$javaopts"
  export JVM_ARGS="$javaopts"


}

run_tomcat (){

  /servers/tomcat/bin/catalina.sh start > /tmp/logme 2>&1

  ( tail -f  /servers/tomcat/logs/catalina.out & ) | grep -q "Server startup in"

  sed_pattern='s/.*Server startup in \(.*\) ms.*/\1/'
  startup_time=$(cat /servers/tomcat/logs/catalina.out | grep "Server startup in"   | sed "$sed_pattern")

}

run_jetty (){

  export JAVA=$JAVA_HOME/bin/java
  # turn on logging
  echo "--module=console-capture" >> /servers/jetty/start.ini

  cp /webapps/* /servers/jetty/webapps
  /servers/jetty/bin/jetty.sh start > /tmp/logme 2>&1

  sed_pattern='s/.*@\(.*\)ms.*/\1/'

  startup_time=$(cat /servers/jetty/logs/*.log | grep "Server:main: Started"   | sed "$sed_pattern")

}


run_openliberty (){

  mkdir -p /servers/openliberty/usr/servers/defaultServer/apps
  cp /webapps/*  /servers/openliberty/usr/servers/defaultServer/apps/ 2>/dev/null


  /servers/openliberty/bin/server start  > /tmp/logme


  ( tail -f /servers/openliberty/usr/servers/defaultServer/logs/messages.log & ) | grep -q "ready to run a smarter planet"

  # log pattern date output by openliberty is subtly different between Java8 and Java 9.
  # not sure why yet.
  # On 9 the log looks date time header looks like "[2/27/18, 12:08:25:123 UTC]"
  # while on 8 its  "[2/27/18 12:08:19:811 UTC]"
  # Note the gained ',' after date for 9


  if [ "$java_runtime_version" == "8" ]
  then
    sed_pattern='s/\.*\[\(.*\) \(.*\):\(.*\):\(.*\):\(.*\) UTC.*/\1 \2:\3:\4\.\5/'
  else
    sed_pattern='s/\.*\[\(.*\), \(.*\):\(.*\):\(.*\):\(.*\) UTC.*/\1 \2:\3:\4\.\5/'
  fi

  start_time=$(cat /servers/openliberty/usr/servers/defaultServer/logs/messages.log  | grep "The server defaultServer has been launched"   | sed "$sed_pattern")
  end_time=$(cat /servers/openliberty/usr/servers/defaultServer/logs/messages.log  | grep "The server defaultServer is ready to run a smarter planet"   | sed "$sed_pattern")

  start_time_nano=$(date "+%s%N" -d "$start_time")
  end_time_nano=$(date "+%s%N"   -d "$end_time")

  let diff=$end_time_nano-$start_time_nano

  startup_time=$( echo "scale=0 ; $diff / 1000000" | bc )


}

# input parsing.
server_type=""
java_runtime=""
java_runtime_version="9"
mode="container"

while getopts ":xhm:j:s:n:v:" opt; do
  case $opt in

    x)
      bash
      exit 1
    ;;
    h)
      echo "run docker java performance test " >&2
      echo "" >&2
      echo "runtests  [ -h ]  [ -d ]  -s server  -j java  " >&2
      echo "" >&2
      echo "-h  for help (this message)" >&2
      echo "-v  java runtime version where option is one of (${java_runtime_versions[*]})" >&2
      echo "-s  server  where option is one of (${servers[*]})" >&2
      echo "-j  java runtime where option is one of (${java_runtimes[*]})" >&2
      echo "-m  run mode. Default is container. Options are " >&2
      echo "    container : quick starting low mem usage " >&2
      echo "    shared    : container mode with a persistent classes cache held outside container " >&2
      echo "    standard  : vanilla Java configuration " >&2

      exit 1
    ;;
    n)  run_number="$OPTARG" ;;

    m)
      if [[ ${modes[*]} =~ "$OPTARG"  ]]
      then
        mode=$OPTARG
      else
        echo "mode option $OPTARG is invalid" >&2
        echo "select from '${modes[*]}' or remove option to use default container mode" >&2
        exit 1
      fi
    ;;
    #
    # server type
    #
    s)
      if [[ ${servers[*]} =~ "$OPTARG"  ]]
      then
        server_type=$OPTARG
      else
        echo "server option $OPTARG is invalid" >&2
        echo "select from '${servers[*]}' " >&2
        exit 1
      fi
    ;;
    #
    # java runtime
    #
    j)
      if [[ ${java_runtimes[*]} =~ "$OPTARG"  ]]
      then
        java_runtime=$OPTARG
      else
        echo "java option $OPTARG is invalid" >&2
        echo "select from '${java_runtimes[*]}' " >&2
        exit 1
      fi
    ;;
    #
    # java version
    #
    v)
      if [[ ${java_runtime_versions[*]} =~ "$OPTARG"  ]]
      then
        java_runtime_version=$OPTARG
      else
        echo "java runtime option $OPTARG is invalid" >&2
        echo "select from '${java_runtime_versions[*]}' " >&2
        exit 1
      fi
    ;;



    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
    ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
    ;;
  esac
done



# set Java runtime config

case $java_runtime in

    "openj9"  ) config_openj9 ;;
    "hotspot" )config_hotspot ;;

    *) echo "java runtime not specified"
    exit 1
    ;;
esac

gather_stats

pre_call

case $server_type in
    "tomcat" )
        run_tomcat ;;
    "jetty" )
        run_jetty ;;
    "openliberty" )
       run_openliberty;;

    *)
    echo "server type not specified"
    exit 1
      ;;

esac


# dont want any horrible process terminated messages
# when we kill the stats collector
# wait 2 secs for last details to be captured
sleep 2
disown -r
kill $stats_tool

# the stats file tends to have an incomplete json data last entry so it is removed before processing
# then we pull out the max usage field, do a descending numberic sort and take the 1st entry
max_usage=$( cat /stats/data  | head -n -1 | jq .memory_stats.max_usage | sort -g -r | head -n 1 )

# adjust statup time by any initial setup costs
if [ -n "${setup_time}" ]; then

  let startup_time=$startup_time+${setup_time}

fi

# server,runtime,statup secs,max mem usage MB

echo "$server_type,$java_runtime,$java_runtime_version,$run_number,$startup_time,$max_usage"
