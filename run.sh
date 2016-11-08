#!/bin/bash

export ROOT=$(cd `dirname $0` ; pwd)

../redis-3.2.5/src/redis-server ../redis-3.2.5/redis.conf

$ROOT/3rd/skynet/skynet $ROOT/server/config