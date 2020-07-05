#!/bin/sh
FOUT=/home/root/rd_metadata.txt
INTERVAL=300
touch $FOUT

while true; do
        echo "measuring...";
        date +%s >> $FOUT;
        /home/root/rd_housekeeping.elf >> $FOUT;

        echo "taking a raw trace...";
        /home/root/rd_rawtrace.elf -D /dev/spidev32765.0 -s 1000000 -o /home/root/rawtraces/$(date +%s).bin -H -O -S 53248;
        sleep $INTERVAL;
done
