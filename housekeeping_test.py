#!/bin/env python3

from pyftdi.spi import SpiController
import time

# start controllre and open an spi port mode 3(cpha=1,cpol=1)
ctrl = SpiController()
ctrl.configure('ftdi://ftdi:232h:1/1')
spi = ctrl.get_port(cs=0, freq=1.25E6, mode=3)

devselect = [0x00, 0x00, 0x00, 0x01]
command   = [0x00, 0b10101011, 0x00, 0x00]

while True:
    res = spi.exchange(devselect+command, 0, True, True)
    print(res)
    time.sleep(1)
