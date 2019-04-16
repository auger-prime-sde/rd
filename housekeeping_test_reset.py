#!/bin/env python3
from pyftdi.spi import SpiController
from pyftdi.spi import SpiGpioPort

import time
import struct
import random
 

# start controllre and open an spi port mode 3(cpha=1,cpol=1)
ctrl = SpiController()
ctrl.configure('ftdi://ftdi:232h:FTU7EF6B/1')
spi = ctrl.get_port(cs=0, freq=5e6, mode=3)
gpio = ctrl.get_gpio()
rst = 8 # blue line
gpio.set_direction(1<<(rst-1), 1<<(rst-1))


i = 1
while True:
    # toggle reset
    gpio.write(gpio.read(True) & (0xff ^ (1<<(rst-1))))
    time.sleep(0.1) # wait for power to be really off
    gpio.write(gpio.read(True) | 1<<(rst-1))
    time.sleep(0.5) # wait for boot

    payload = random.randint(0,255) # inclusive
    # write byte to gpio peripheral of board
    spi.exchange([0x01, 0x01, payload], 0, True, True)
    # read byte back:
    response = spi.exchange([0x01, 0x00, 0x00], 1, True, True)
    if response[0] != payload:
        print("Error: sent {} but received {}".format( hex(payload), hex(response[0])))

    print("\rRandom write/read tests: {:d}".format(i), end="", flush=True)
    i = i+1
    #time.sleep(0.005) # not strictly necessary but it's nice to see the leds blink
