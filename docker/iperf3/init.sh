#!/bin/sh

echo "The actual base image is:"
cat /etc/os-release

echo "iperf3 Version:"
iperf3 --version | head -n 1

if [ "$IPERF_MODE" = "server" ]; then
  echo "Init iperf3 server mode"
  iperf3 -s
else
  echo "Init iperf3 client mode, host = $SERVER_HOST"
  iperf3 -c ${SERVER_HOST}
fi
