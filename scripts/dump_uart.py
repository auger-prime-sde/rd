#!/usr/bin/env python3

import serial
dev = serial.Serial('/dev/ttyUSB0', 5000000, bytesize=7)

while True:
    raw = dev.read(4)
    #print(raw[2])
    #print(raw[3])
    print(raw[2])
    print(raw[3])
    ch1 = raw[1] << 7 + raw[0]
    ch2 = raw[3] << 7 + raw[2]
    #print(hex(ch2))
    # print(hex(ch2))

