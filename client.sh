#!/bin/bash

export ROOT=$(cd `dirname $0` ; pwd)

$ROOT/3rd/skynet/3rd/lua/lua $ROOT/client/client.lua $1 $2
