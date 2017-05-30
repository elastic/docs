#!/bin/bash
# Get latest code 
cd /home/rawengwww/temp/docs && CURRENT="$(git symbolic-ref --short HEAD)" && git fetch && git reset --hard origin/$CURRENT
