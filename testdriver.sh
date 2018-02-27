#!/bin/bash

servers=(jetty openliberty tomcat)
java=(openj9 hotspot)
version=(8 9)
modes=(container standard shared)
test_runs=1
mode="container"
shell_mode=false
image="docker_java_spf:latest"
cachepath="$PWD/.cache"
results_file="results.csv"

while getopts ":xhj:s:v:w:n:m:f:" opt; do
  case $opt in

    x) shell_mode=true ;;
    h)
      echo "run docker java performance tests. Run specificed combinations of Java runtimes and servers" >&2
      echo "" >&2
      echo "runtests  [ -h ]  [ -s server ] [ -j java] [ -w webapp_path ][ -d ]" >&2
      echo "" >&2
      echo "-h  for help (this message)" >&2
      echo "-s  server  where option is one of (${servers[*]})" >&2
      echo "-j  java  where option is one of (${java[*]})" >&2
      echo "-v  version  where option is one of (${version[*]})" >&2
      echo "-w  overiding webapps path " >&2
      echo "-f  name of results file to create in results directory (defaults to results.csv) " >&2
      echo "    contents of path are copied into app server webapps directory " >&2
      echo "-m  run mode default is container. Options are " >&2
      echo "    container : quick starting low mem usage " >&2
      echo "    shared    : container mode with a persistent classes cache held outside container " >&2
      echo "    standard  : vanilla Java configuration " >&2
      echo "-n  number of tests to run" >&2
      exit 1
    ;;


    n) test_runs="$OPTARG" ;;
    w) webpath="$OPTARG" ;;
    f) results_file="$OPTARG" ;;

    s)

      if [[ ${servers[*]} =~ "$OPTARG"  ]]
      then
        servers=($OPTARG)
      else
        echo "server option $OPTARG is invalid" >&2
        echo "select from '${servers[*]}' or remove option to use all " >&2
        exit 1
      fi
    ;;

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
    j)
      if [[ ${java[*]} =~ "$OPTARG"  ]]
      then
        java=($OPTARG)
      else
        echo "java option $OPTARG is invalid" >&2
        echo "select from '${java[*]}' or remove option to use all " >&2
        exit 1
      fi
    ;;


    v)
      if [[ ${version[*]} =~ "$OPTARG"  ]]
      then
        version=($OPTARG)
      else
        echo "java option $OPTARG is invalid" >&2
        echo "select from '${version[*]}' or remove option to use all " >&2
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

#
# build base docker command
#

command="  docker run -it -v /var/run/docker.sock:/var/run/docker.sock "


# add any overide for a webapps path
#
if [ -n "${webpath}" ]; then
  command="$command -v ${webpath}:/webapps"
fi

# add any overide for a cache path if needed
#
if [ "$mode" == "shared" ]; then
  rm -rf ${cachepath}
  mkdir -p ${cachepath}
  command="$command -v ${cachepath}:/cache"
fi

# add docker image name
command="$command $image"

#
# if shell mode we call the docker container now
# and then exit
#

if [ $shell_mode = true ]; then

  command="$command -x"
  echo $command
  ${command}

  exit 1
fi


echo "Running tests"
echo "repeating $test_runs time(s)"
echo "servers  : ${servers[*]}"
echo "java     : ${java[*]}"
echo "version  : ${version[*]}"

mkdir -p results
outputfile="results/$results_file"

echo "server,runtime,version,cache run,statup ms,max mem usage bytes" > $outputfile

for n in $(seq 1 $test_runs) ; do
  echo "Pass $n / $test_runs"
  for s in  "${servers[@]}" ; do
    for j in  "${java[@]}"  ; do
      for v in  "${version[@]}"  ; do
        echo "running $s with $j  version $v"
        $command  -j $j -s $s -v $v -n $n -m $mode >> $outputfile
       done
     done
  done
done
