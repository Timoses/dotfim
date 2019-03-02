#!/bin/bash

set -e

docker build -t dotfim_test -f test.dockerfile ../
docker run -it --rm --env DOTFIM_LOCALINFO=`hostname` -v $(dirname `pwd`):/source dotfim_test
