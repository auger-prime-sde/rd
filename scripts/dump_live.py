#!/usr/bin/env python3

import serial
import time
import numpy as np
import matplotlib.pyplot as plt
import scipy.signal as sig
from pprint import pprint
import sys
import os

## Number of FFTs to average
averages = 1

dev          = serial.Serial()
if os.name == 'nt' :
    dev.port     = 'COM9'
else:
    dev.port  = '/dev/ttyUSB1'
dev.baudrate = int(6.05e6)
dev.timeout  = 1
dev.open()
dev.write("r".encode('utf-8'))

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
    dev.write("T".encode('utf-8'))
    dev.flush()
    #time.sleep(0.01)
    #dev.write("t".encode('utf-8'))

def start_transfer():
    dev.write("x".encode('utf-8'))
    #time.sleep(0.01)
    dev.write("x".encode('utf-8'))

def dump_to_uart():
    dev.write("d".encode('utf-8'))
    dev.flush()

##
# Convert a single sample value (as 2 byte pair) into a signed integer representation
##
def val_from_raw(raw1, raw0):
    val_unsigned = ((raw0 & 0x3F) << 6) + (raw1 & 0x3F)
    bits0 = bin(raw0)[2:]
    bits1 = bin(raw1)[2:]
    numones = len([x for x in bits0+bits1 if x=='1'])
    #print("raw: {} {}".format(bin(raw0)[2:].rjust(8,'0'),bin(raw1)[2:].rjust(8,'0')))
    #print("numones: {}".format(numones))
    #if (numones % 2) == 0:
    #    print("parity mismatch!")
    if val_unsigned > 2047:
        return val_unsigned - 4096
    else:
        return val_unsigned

def parity_from_raw(raw1, raw0):
    val_unsigned = ((raw0 & 0x3F) << 6) + (raw1 & 0x3F)
    bits0 = bin(raw0)[2:]
    bits1 = bin(raw1)[2:]
    numones = len([x for x in bits0+bits1 if x=='1'])
    return numones % 2


##
# Trigger the digitizer and read the resulting set of samples from the UART.  Return a list of samples for each channel separately.
#
# Usage: (ch1, ch2) = read_samples()
##
def read_samples():
    ch1_data = []
    ch2_data = []

    dump_to_uart()

    par0,par1 = 0,0
    for b in range(2048):
        raw = dev.read(2)
        #print("raw: {} {}".format(bin(raw[0]), bin(raw[1])))
        ch1 = val_from_raw(raw[1], raw[0])
        par0 += parity_from_raw(raw[1], raw[0])
        ch1_data.append(ch1)

    for b in range(2048):
        raw = dev.read(2)
        #print("raw: {}".format(raw))
        ch2 = val_from_raw(raw[1], raw[0])
        par1 += parity_from_raw(raw[1], raw[0])
        ch2_data.append(ch2)
        #print("{0:06b} {1:07b} = {2}".format(raw[0], raw[1], ch2))

    par0 = 2048 - par0
    par1 = 2048 - par1
    print("parity check errors: {} {}".format(par0, par1))
    #pprint("raw data:")
    #for i in range(100):
    #    print("{0:b}".format(ch2_data[i]))
    #pprint(ch1_data[0:99])
    #pprint(ch2_data[0:99])

    print("done")
    #dev.timeout = 1
    #junk = dev.read(10000)
    #print("%d bytes remained in buffer after read"%len(junk))
    return (ch1_data, ch2_data)


##
# Compute the FFT of a sample sequence and plot it using matplotlib.
##
def fft_from_samples(data, plotraw=True):
    # Scale data to voltages
    y = np.asarray(data) / 2048. * 2.0/2.0;

    # Number of samplepoints
    N = len(y)
    # sample spacing
    T = 1.0 / 250.0
    x = np.linspace(0.0, N*T, N)
    xf = np.linspace(0.0, 1.0/(2.0*T), int(N/2))

    if plotraw:
        fix,ax = plt.subplots()
        line = (ax.plot(x,y))[0]
        line.set_marker("o")
        line.set_markersize(3)
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


def make_fft_plot(xf):
    global line1, line2, marker1, marker2, fig, background, ax, text
    # Start plotting things
    fig, ax = plt.subplots()
    line1, = ax.plot(xf, np.zeros(len(xf)), label='ch0')
    line2, = ax.plot(xf, np.zeros(len(xf)), label='ch1')
    ax.set_ylabel("power (dBm)")
    ax.set_xlabel("frequency (MHz)")
    ax.set_ylim(-110.0,10.0)
    text = ax.text(0, 0, "")

    # Locate peak values
    marker1, = ax.plot(0, 0, "ro")
    marker2, = ax.plot(0, 0, "ro")

    # add legend
    ax.legend()
    
t_prev = 0
def update_fft_plot(ypow0, ypow1):
    global line1, line2, marker1, marker2, fig, text, t_prev
    line1.set_ydata(ypow0)
    line2.set_ydata(ypow1)

    # Locate peak values
    peak = np.argmax(ypow0)
    marker1.set_xdata(xf[peak])
    marker1.set_ydata(ypow0[peak])
    peak = np.argmax(ypow1)
    marker2.set_xdata(xf[peak])
    marker2.set_ydata(ypow1[peak])

    t_this = time.time()
    tx = 'Mean Frame Rate:\n {fps:.3f}FPS'.format(fps= ((1) / (t_this - t_prev)))  
    text.set_text(tx)
    t_prev = t_this
    
    fig.canvas.draw()
    fig.canvas.flush_events()
    

##
# Example run code
##

## prepare empty plots
N = 2048
T = 1.0 / 250.0
x = np.linspace(0.0, N*T, N)
xf = np.linspace(0.0, 1.0/(2.0*T), int(N/2))
make_fft_plot(xf)

##
# Fix plotting in interactive mode...
#if in_ipython():
plt.ion()

##
# Show results
plt.show()

while True:
    ypow0 = np.zeros(1024, dtype='float')
    ypow1 = np.zeros(1024, dtype='float')

    start = time.time()
    ends = []
    for i in range(0, averages):
        #time.sleep(0.02)
        dev.reset_input_buffer()
        
        trigger()
        start_transfer()
        
        startread = time.time()
        (ch0, ch1) = read_samples()
        print("read samples: {}".format(time.time()-startread))

        #pprint(ch1)
        #pprint([(s) for s in ch1])
        (xf, ypow0_new) = fft_from_samples(ch0, False)
        (xf, ypow1_new) = fft_from_samples(ch1, False)

        ypow0 += ypow0_new
        ypow1 += ypow1_new
        ends.append(time.time())

    print("whole update routine {}".format(ends[0]-start))

    ypow0 /= averages
    ypow1 /= averages
    
    update_fft_plot(ypow0, ypow1)

