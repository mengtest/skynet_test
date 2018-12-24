#!/bin/bash

export ROOT=$(cd `dirname $0` ; pwd)
export DAEMON=false

while getopts "Dk" arg
do
	case $arg in
		D)
			export DAEMON=true
			;;
		k)
			kill `cat $ROOT/server-login/run/skynet.pid`
			exit 0;
			;;
	esac
done

$ROOT/3rd/skynet/skynet $ROOT/server-login/config
