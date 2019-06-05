#!/bin/env python3

from pyftdi.spi import SpiController
import time
import struct
import sys, termios, tty, os
 

# start controllre and open an spi port mode 3(cpha=1,cpol=1)
ctrl = SpiController()
ctrl.configure('ftdi://ftdi:232h:FTU7EF6B/1')
spi = ctrl.get_port(cs=0, freq=5E6, mode=3)

f = open("dump.bin", "wb")
numbytes = 4 * 1024 * 1024 # 32 mbits, 4 mbytes
bytesperpacket = 65536 # experimentally determined largest exponent of 2 that the spi dongle supports
numpackets = int(numbytes / bytesperpacket)
for i in range(numpackets):
    print("\rProgress: {:5.2f}% ".format(100.0 * i / numpackets), end="", flush=True)
    addr = i * bytesperpacket
    addrbytes = struct.pack(">I", addr)[1:] # last 3 bytes only. ">" means MSB, "I" means uint32
    commandbytes = bytes([0x02, 0x03]) # 0x02 selects flash, 0x03 is spi flash read command
    res = spi.exchange(commandbytes+addrbytes, bytesperpacket, True, True)
    f.write(res)
print("\rProgress: 100%                       ")
f.close()
    
