#!/usr/bin/env python3

import serial
import time
dev          = serial.Serial()
dev.port     = '/dev/ttyUSB0'
dev.baudrate = 115200
dev.timeout  = 1
dev.bytesize = 7
dev.dtr      = 1 
dev.open()

def trigger():
    dev.dtr = 0
    #time.sleep(0.001)
    dev.dtr = 1


    
def read_sample():
    time.sleep(2)
    dev.reset_input_buffer()
    trigger()
   
    for b in range(2048):
        raw = dev.read(4)
        #print(raw[2])
        #print(raw[3])
        #print(raw[2])
        #print(raw[3])
        print("%04d: % 3d % 3d % 3d % 3d"%(b,raw[0], raw[1], raw[2], raw[3]))
        #ch1 = (raw[1] << 7) + raw[0]
        #ch2 = (raw[3] << 7) + raw[2]
        #print("%04d: %06d %06d"%(b, ch1,ch2))


    print("done")
    dev.timeout = 1
    junk = dev.read(10000)
    print("%d bytes remained in buffer after read"%len(junk))

