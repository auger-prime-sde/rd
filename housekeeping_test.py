#!/bin/env python3

from pyftdi.spi import SpiController
import time
import sys, termios, tty, os
 

# start controllre and open an spi port mode 3(cpha=1,cpol=1)
ctrl = SpiController()
ctrl.configure('ftdi://ftdi:232h:FTU7EF6B/1')
spi = ctrl.get_port(cs=0, freq=1E6, mode=3)

# other commands:
# [0x03, 0b10100000, 0x01] read=1  read adc id, should be 0x82

while True:
    print("Command: ", end="", flush=True)
    l = sys.stdin.readline()
    # some shortcuts for common commands:
    if l.startswith("i"): # all leds off
        bytes_out = [0x01, 0x01, 0xFF]
        count_in  = 0
    elif l.startswith("o"): # all leds on
        bytes_out = [0x01, 0x01, 0x00]
        count_in  = 0
    elif l.startswith("r"): # read led state
        bytes_out = [0x01, 0x00, 0x00]
        count_in  = 1
    elif l.startswith("j"): # read flash jedec id
        bytes_out = [0x02, 0x9F]
        count_in = 3
    elif l.startswith("s"): # read flash status reg
        bytes_out = [0x02, 0x05]
        count_in = 4
    elif l.startswith("c"): # read flash config ref
        bytes_out = [0x02, 0x35]
        count_in = 4
    elif l.startswith("ar"):
        bytes_out = [0x03, 0x00, 0x01]
        count_in = 0
    elif l.startswith("a2"):
        bytes_out = [0x03, 0x02]
        count_in = 1
    elif l.startswith("h"):
        bytes_out = [0x04, 0x00]
        count_in = 1
    elif l.startswith("l"):
        bytes_out = [0x04, 0x01]
        count_in = 1
    #elif l.startswith("h1"):
    #    bytes_out = [0x04, 0x80, 0x00, 0x00]
    #    count_in  = 2
    #elif l.startswith("h2"):
    #    bytes_out = [0x04, 0x90, 0x00, 0x00]
    #    count_in  = 2
    #elif l.startswith("h3"):
    #    bytes_out = [0x04, 0xA0, 0x00, 0x00]
    #    count_in  = 2
    #elif l.startswith("h4"):
    #    bytes_out = [0x04, 0xB0, 0x00, 0x00]
    #    count_in  = 2
    else: # the option to enter bytes manually
        try:
            bytes_out = [int(w,0) for w in l.split()]
            print("How many bytes to read: ", end="", flush=True)
            l = sys.stdin.readline()
            count_in = int(l)
        except:
            print("FAILED TO PARSE!\n")
            continue
    
    res = spi.exchange(bytes_out, count_in, True, True)
    if count_in > 0:
        print("result (int): ", end="", flush=True)
        print([x for x in res])
        print("result (hex): ", end="", flush=True)
        print([hex(x) for x in res])
        print("result(char): ", end="", flush=True)
        print([chr(x) for x in res])
        print("result (bin): ", end="", flush=True)
        print([bin(x) for x in res])

    print()
    time.sleep(0.2)

