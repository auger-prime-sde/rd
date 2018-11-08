#!/usr/bin/env python3

import serial
import time
import numpy as np
import matplotlib.pyplot as plt
import scipy.signal as sig
from pprint import pprint


## Number of FFTs to average
averages = 10


dev          = serial.Serial()
dev.port     = '/dev/ttyUSB1'
dev.baudrate = 1e6 #115200
dev.timeout  = 1
dev.open()

##
# Detect if we're running in interactive mode to avoid problems with matplotlib
##
def in_ipython():
    try:
        __IPYTHON__
    except NameError:
        return False
    else:
        return True
##
# Trigger the digitizer using the DTR line on the UART.  The DTR line is active low so writing a 0 here gives a 1 on the physical line.
##
def trigger():
    dev.write("t".encode('utf-8'))
    time.sleep(0.1)
    dev.write("t".encode('utf-8'))

def start_transfer():
    dev.write("x".encode('utf-8'))
    time.sleep(0.1)
    dev.write("x".encode('utf-8'))

def dump_to_uart():
    dev.write("d".encode('utf-8'))
    
##
# Convert a single sample value (as 2 byte pair) into a signed integer representation
##
def val_from_raw(raw1, raw0):
  val_unsigned = ((raw0 & 0x3F) << 6) + (raw1 & 0x3F)
  if val_unsigned > 2047:
    return val_unsigned - 4096
  else:
    return val_unsigned

##
# Trigger the digitizer and read the resulting set of samples from the UART.  Return a list of samples for each channel separately.
#
# Usage: (ch1, ch2) = read_samples()
##
def read_samples():
    ch1_data = []
    ch2_data = []

    dump_to_uart()
     
    for b in range(2048):
        raw = dev.read(2)
        #pprint(raw)
        ch1 = val_from_raw(raw[1], raw[0])
        ch1_data.append(ch1)

    for b in range(2048):
        raw = dev.read(2)
        ch2 = val_from_raw(raw[1], raw[0])
        ch2_data.append(ch2)

    pprint("raw data:")
    pprint(ch1_data[0:99])
    pprint(ch2_data[0:99])
    
    print("done")
    #dev.timeout = 1
    #junk = dev.read(10000)
    #print("%d bytes remained in buffer after read"%len(junk))
    return (ch1_data, ch2_data)

##
# Compute the FFT of a sample sequence and plot it using matplotlib.
##
def fft_from_samples(data):
    # Scale data to voltages
    y = np.asarray(data) / 2048. * 1.75/2.0;

    # Number of samplepoints
    N = len(y)
    # sample spacing
    T = 1.0 / 200.0
    x = np.linspace(0.0, N*T, N)
    xf = np.linspace(0.0, 1.0/(2.0*T), N/2)

    fix,ax = plt.subplots()
    ax.plot(x,y)
    ax.set_xlabel("time (us)")
    ax.set_ylabel("V")
  
    # Apply windowing function (7-term Blackman-Harris)
    # Compute FFT, default size = data size
    w = np.zeros((N), dtype='float')
    for n in np.arange(0, N):
        w[n] = 0.27105140069342 \
             - 0.43329793923448 * np.cos(   2.*np.pi*n/N) \
             + 0.21812299954311 * np.cos(2.*2.*np.pi*n/N) \
             - 0.06592544638803 * np.cos(3.*2.*np.pi*n/N) \
             + 0.01081174209837 * np.cos(4.*2.*np.pi*n/N) \
             - 0.00077658482522 * np.cos(5.*2.*np.pi*n/N) \
             + 0.00001388721735 * np.cos(6.*2.*np.pi*n/N)

    # Coherent gain
    CPG = np.sum(w)/N
    CPGdB = -20*np.log10(CPG)

    # Compute FFT with windowing applied
    # Divide by N to compensate for FFT scaling
    yf = np.fft.fft(y*w) / N

    # Translate to power dBm in 50R, fold spectrum to single band, and convert into dB
    ypowl = 2*1000*np.abs(yf[:N//2])**2/50
    ypow = 10*np.log10(ypowl)

    return (xf, ypow+CPGdB)


def print_fft(xf, ypow):
    # Start plotting things
    fig, ax = plt.subplots()
    ax.plot(xf, ypow)
    ax.set_ylabel("power (dBm)")
    ax.set_xlabel("frequency (MHz)")

    # Locate peak value
    peak = np.argmax(ypow)
    ax.plot(xf[peak], ypow[peak], "ro")

    
##
# Example run code
##
ypow = np.zeros(1024, dtype='float')
for i in range(0, averages):
    time.sleep(0.1)
    dev.reset_input_buffer()
    trigger()
    time.sleep(0.1)
    start_transfer()
    time.sleep(0.1)
   
    
    (ch1, ch2) = read_samples()
    (xf, ypow_new) = fft_from_samples(ch1)
    ypow += ypow_new

ypow = ypow / averages

print_fft(xf, ypow)
#print_fft(xf, xt)

##
# Fix plotting in interactive mode...
if in_ipython():
    plt.ion()

##
# Show results
plt.show()

