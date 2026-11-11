#!/bin/bash
cd /root/fbcp-ili9341/build

# Attempt 1 - wake up the screen (cold start)
./fbcp-ili9341 &
PID1=$!
sleep 3
kill -INT $PID1
sleep 1

# Attempt 2 - stabilize the panel logic
./fbcp-ili9341 &
PID2=$!
sleep 3
kill -INT $PID2
sleep 1

# Attempt 3 - final launch in background
./fbcp-ili9341 > /dev/null 2>&1 &
