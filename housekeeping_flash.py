#!/bin/env python3

from pyftdi.spi import SpiController
import time
import struct
import sys, termios, tty, os
import math

if len(sys.argv) < 3:
    print("Usage: python housekeeping_flash.py [dump | upload] file")
    sys.exit(-1)

action = sys.argv[1]
filename = sys.argv[2]


# start controllre and open an spi port mode 3(cpha=1,cpol=1)
ctrl = SpiController()
ctrl.configure('ftdi://ftdi:232h:FTU7EF6B/1')
spi = ctrl.get_port(cs=0, freq=5E6, mode=3)

if action == "dump":
    f = open(filename, "wb")
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
elif action == "upload":
    f = open(filename, "rb")
    numbytes = os.path.getsize(filename)

    # clear all write protect bits:
    # TODO: only clear the bits that are needed
    spi.exchange(bytes([0x02, 0x06]), 0, True, True)
    spi.exchange(bytes([0x02, 0x98]), 0, True, True)
    # BPR should be 0x5500_BFFFFFFF_80000000_????????_????
    # complete write sequence:
    # 0x02 0x06
    # 0x02 0x42 0x55 0x00 0xBF 0xFF 0xFF 0xFF 0x80 0x00 0x00 0x00 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF
    
    # erase needed sectors:
    bytespersector = 4096
    numsectors = math.ceil(numbytes / bytespersector)
    for i in range(numsectors):
        print("\rClearing: {:5.2f}% ".format(100.0 * i / numsectors), end="", flush=True)
        addr = i * bytespersector
        commandbytes = bytes([0x02, 0x20])
        addrbytes = struct.pack(">I", addr)[1:]
        print("\nsector: {} \taddr: {} \taddr bytes: {}".format(i, addr, addrbytes))
        # TODO: figure out if this is correct. hint: probably not...
        spi.exchange(bytes([0x02, 0x06]), 0, True, True)
        spi.exchange(commandbytes+addrbytes, 0, True, True)
        time.sleep(0.05)
    print("\rClearing: 100%                    ")

    # write the data:
    bytesperpacket = 256 # writes are limited to pages of this size
    numpackets = math.ceil(numbytes / bytesperpacket)
    for i in range(numpackets):
        print("\rWriting: {:5.2f}% ".format(100.0 * i / numpackets), end="", flush=True)
        addr = i * bytesperpacket
        addrbytes = struct.pack(">I", addr)[1:]
        commandbytes = bytes([0x02, 0x02])
        databytes = f.read(bytesperpacket)
        if len(databytes) < bytesperpacket:
            databytes += (bytesperpacket - len(databytes)) * b'\xFF'
        spi.exchange(bytes([0x02, 0x06]), 0, True, True)
        spi.exchange(commandbytes+addrbytes+databytes, 0, True, True)
        time.sleep(0.003)
    print("\rWriting: 100%                         ")

    # TODO: put write protects back in place
    
