#!/bin/env python3

from pyftdi.spi import SpiController
import time
import sys, termios, tty, os
 
def getch():
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(sys.stdin.fileno())
        ch = sys.stdin.read(1)
 
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    return ch
 

# start controllre and open an spi port mode 3(cpha=1,cpol=1)
ctrl = SpiController()
ctrl.configure('ftdi://ftdi:232h:1/1')
spi = ctrl.get_port(cs=0, freq=5E6, mode=3)

ledstate = 0x00
devselect_leds  = [0x00, 0x00, 0x00, 0x01]
devselect_flash = [0x00, 0x00, 0x00, 0x02]
#devselect2 = [0b00010001, 0b00000000, 0b11111111, 0b10101010]
writecommand = [0b00000001, ledstate, 0x00, 0x00]
readcommand  = [0b00000000, 0x00, 0x00, 0x00]  # technically this sets bits but with 0x00 it does nothing
clearcommand = [0xFF, 0x00, 0x00, 0x00] # caught by the decoder. 
#command2   = [0x00, 0b00000000, 0x00, 0x00]



while True:
    print("What to do:\nt\tToggle Leds\nr\tRead led state\nc\tClear fault state")
    c = getch()
    if 't' == c:
        ledstate = 0xFF if ledstate==0x00 else 0x00
        writecommand[1] = ledstate
        res = spi.exchange(devselect_leds+writecommand, 0, True, True)
        print(res)
    if '1' == c:
        #ledstate = 0xFF if ledstate==0x00 else 0x00
        writecommand[1] = 0xFF
        res = spi.exchange(devselect_leds+writecommand, 0, True, True)
        print(res)
    if '0' == c:
        writecommand[1] = 0x00
        res = spi.exchange(devselect_leds+writecommand, 0, True, True)
        print(res)
    if 'r' == c:
        res = spi.exchange(devselect_leds+readcommand, 4, True, True)
        print(res)
    if 'c' == c:
        res = spi.exchange(devselect_leds+clearcommand, 0, True, True)
        print(res)
        
    time.sleep(0.2)

