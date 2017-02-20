#!/bin/bash

export ROOT=$(cd `dirname $0` ; pwd)

../redis-3.2.7/src/redis-server ./tools/redis.conf

$ROOT/3rd/skynet/skynet $ROOT/server/config
