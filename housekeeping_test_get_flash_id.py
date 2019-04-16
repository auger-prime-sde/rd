
from pyftdi.spi import SpiController
import time

# start controllre and open an spi port mode 3(cpha=1,cpol=1)
ctrl = SpiController()
ctrl.configure('ftdi://ftdi:232h:1/1')
spi = ctrl.get_port(cs=0, freq=5E6, mode=3)

devselect = [0x00, 0x00, 0x00, 0x02]
command   = [0x9F, 0x00, 0x00, 0x00]

while True:
    input("Press Enter to continue...")

    res = spi.exchange(devselect+command, 0, True, True)
    print(res)
