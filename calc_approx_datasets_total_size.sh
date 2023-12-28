#!/bin/bash

echo "Approximate restore size of all datasets:"
tot=0
for rs in $(find . -iname 'restore_size') ; do
  gb=$(cat $rs)
  tot=$((tot+gb))
done
echo "$((tot/1000)) GB"

echo "Approximate download size of all datasets:"
tot=0
for rs in $(find . -iname 'dump_size') ; do
  gb=$(cat $rs)
  tot=$((tot+gb))
done
echo "$((tot/1000)) GB"
