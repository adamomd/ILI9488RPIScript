#!/bin/bash
cd /root/fbcp-ili9341/build

# Próba 1 - wybudzenie ekranu (zimny start)
./fbcp-ili9341 &
PID1=$!
sleep 3
kill -INT $PID1
sleep 1

# Próba 2 - stabilizacja logiki matrycy
./fbcp-ili9341 &
PID2=$!
sleep 3
kill -INT $PID2
sleep 1

# Próba 3 - ostateczne uruchomienie w tle
./fbcp-ili9341 > /dev/null 2>&1 &
