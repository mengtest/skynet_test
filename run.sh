#!/bin/bash

echo "Hello World"
export ROOT=$(cd `dirname $0` ; pwd)

$ROOT/3rd/skynet/skynet $ROOT/server/config