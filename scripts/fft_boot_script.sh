#!/bin/bash

BASEDIR=/home/root
#BASEDIR=/usb
FFTDIR=$BASEDIR/ffts
INTERVAL=150

mountusb
cd $BASEDIR
mkdir -p $FFTDIR

# update RD firmware if necessary
./rd_flash.elf -w rd_firmware_v5.bit -n 5
# power cycle RD
slowc -P0x033f
slowc -P0x03ff


# main loop
while true; do
	NOW=$(date +%s)
	# record some metadata
	./rd_housekeeping.elf >> $FFTDIR/hk_${NOW}.txt
	# record some fft's
	./rd_fft_readout.elf -W 64 -S 512 -o $FFTDIR/fft_T7_${NOW}.bin -m 8192 -t 200
	# sync filesystems
	sync
	# and sleep
	sleep $INTERVAL

	# now repeat but save the T=200 trace and set T back to 7
	NOW=$(date +%s)
	# record some metadata
	./rd_housekeeping.elf >> $FFTDIR/hk_${NOW}.txt
	# record some fft's
	./rd_fft_readout.elf -W 64 -S 512 -o $FFTDIR/fft_T200_${NOW}.bin -m 8192 -t 7
	# sync filesystems
	sync
	# and sleep
	sleep $INTERVAL
done

