#!/bin/env python3

from pyftdi.spi import SpiController
import time
import sys, termios, tty, os
import serial

# start serial port
ser = serial.Serial('/dev/ttyUSB1', 2015000)  # open serial port

# start controllre and open an spi port mode 3(cpha=1,cpol=1)
ctrl = SpiController()
ctrl.configure('ftdi://ftdi:232h:FTU7EF6B/1')
spi = ctrl.get_port(cs=0, freq=1E6, mode=3)
    

while True:
    ser.write(b'T') # due to a bug 2 triggers are needed 
    ser.write(b'T')
    
    h = spi.exchange([0x04, 0x00], 1, True, True)[0]
    l = spi.exchange([0x04, 0x01], 1, True, True)[0]

    print("current register value: {}".format((h<<4)+(l>>4)))
    time.sleep(0.5)

    
ser.close()
