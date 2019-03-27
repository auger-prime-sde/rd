#!/bin/env python3

from pyftdi.spi import SpiController
import time

# start controllre and open an spi port mode 3(cpha=1,cpol=1)
ctrl = SpiController()
ctrl.configure('ftdi://ftdi:232h:1/1')
spi = ctrl.get_port(cs=0, freq=1.25E6, mode=3)

devselect1 = [0x00, 0x00, 0x00, 0x01]
devselect2 = [0b00010001, 0b00000000, 0b11111111, 0b10101010]
command1   = [0x00, 0b10101011, 0x00, 0x00]
command2   = [0x00, 0b00000000, 0x00, 0x00]

while True:
    res = spi.exchange(devselect1+command1, 0, True, True)
    print(res)
    time.sleep(1)
    res = spi.exchange(devselect1+command2, 0, True, True)
    print(res)
    time.sleep(1)
    res = spi.exchange(devselect2+command1, 0, True, True)
    print(res)
    time.sleep(1)
