#!/bin/bash

export ROOT=$(cd `dirname $0` ; pwd)

int=0
account=hello
name=ding
while (($int<=1000))
do
{
  let "int++"
  $ROOT/client.sh ${account}"0" ${name}"0"
}
done
