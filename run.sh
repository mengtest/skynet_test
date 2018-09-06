#!/bin/bash

export ROOT=$(cd `dirname $0` ; pwd)

../redis/src/redis-server ./tools/redis.conf

#service mysql start

$ROOT/3rd/skynet/skynet $ROOT/server/config
