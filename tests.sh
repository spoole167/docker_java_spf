#
# Test 1
# OpenJDK 8  jetty with hotspot vs openj9 no container magic

# ./testdriver.sh -v 8 -m standard -s jetty -f jetty_java8_hv9_standard

#
# Test 2
#
# OpenJDK 9  jetty with hotspot vs openj9 no container magic

# ./testdriver.sh -v 9 -m standard -s jetty -f jetty_java9_hv9_standard

#
# Test 3
# OpenJdk 9  jetty with hotspot vs openj9 full container magic with shared cache

./testdriver.sh -v 9  -m shared  -n 2 -f all_java9_hv9_shared_n2  
