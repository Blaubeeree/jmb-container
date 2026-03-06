#!/bin/bash
#docker build . 2>&1 | tee build.log
DOCKER_BUILDKIT=1 docker build -t chrisb09/jmusicbot . "${@:1}" 2>&1 | tee build.log
if [ "$1" != "--no-cache" ]; then
  echo " use --no-cache to disable cache"
fi
