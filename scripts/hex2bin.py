#!/bin/env python3
import sys
import numpy as np

if len(sys.arv) < 2:
    print("Usage: {:} <intel hex file>".format(sys.argv[0]))
    sys.exit(0)

buffer = np.array([], np.uint8)
offset = 0
with f as open(sys.argv[1]):
    for line in f:
        datalen  = int(line[1:3], 16)
        dataaddr = int(line[3:7], 16)
        command  = int(line[7:9], 16)
        data = line[9:(9+2*datalen)]

        if command == 0x00:
            # write data:
            addr = ((offset & 0xFF) << 16) + (dataaddr & 0xFFFF)
            if addr+datalen > len(buffer):
                buffer.resize([addr+datalen])
                print("resized to {:}".formar(len(buffer)))
            buffer[]
        


