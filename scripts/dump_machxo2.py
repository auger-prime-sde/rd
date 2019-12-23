#!/usr/bin/env python3

import serial
import time
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import scipy.signal as sig
from pprint import pprint
import sys


## Number of FFTs to average
averages = 1
dev = None

def open_serial():
    global dev
    dev          = serial.Serial()
    dev.port     = '/dev/ttyUSB1'
    dev.baudrate = int(2.015e6)
    dev.timeout  = 1
    dev.open()
    dev.write("r".encode('utf-8')) # reset parity error counters in debug board

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
    global dev
    dev.write("T".encode('utf-8'))
    dev.flush()
    #time.sleep(0.0002)
    #dev.write("t".encode('utf-8'))

def dump_to_uart():
    global dev
    dev.reset_input_buffer()
    dev.write("d".encode('utf-8'))

    
##
# Read and decompose input bytes. Returns a numpy array with, for each sample number, two sample values, 2 parity checks and 2 trigger bits
##
def read_buffer():
    dump_to_uart()
    data = np.zeros((2048, 6)) # for each sample 2 channel values, 2 parity checks and 2 trigger bits
    for ch in range(2):
        for b in range(2048):
            raw = dev.read(2)
            val_unsigned = ((raw[0] & 0x3F) << 6) + (raw[1] & 0x3F)
            if val_unsigned > 2047:
                val_unsigned = val_unsigned - 4096
            bits = bin(raw[0]) + bin(raw[1])
            numones = len([x for x in bits if x=='1'])
            data[b, 0+ch] = val_unsigned
            data[b, 2+ch] = 1 - (numones % 2)
            # for debugging
            #print("ch{} sample {:4d}: raw: {:08b} {:08b} val: {:5d} {}".format(ch, b, raw[0], raw[1], val_unsigned, "parity ok" if numones % 2 == 1 else "Parity FAIL" ))
    return data


##
# Compute the FFT of a sample sequence and plot it using matplotlib.
##
def fft_from_samples(data):
    # Scale data to voltages
    y = np.asarray(data) / 2048. * 2.0/2.0;

    # Number of samplepoints
    N = len(y)
    # sample spacing
    T = 1.0 / 250.0
    x = np.linspace(0.0, N*T, N)
    xf = np.linspace(0.0, 1.0/(2.0*T), N/2)

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


def print_fft(xf, ypow0, ypow1):
    # Start plotting things
    fig, ax = plt.subplots()
    ax.plot(xf, ypow0, label='ch0')
    ax.plot(xf, ypow1, label='ch1')
    ax.set_ylabel("power (dBm)")
    ax.set_xlabel("frequency (MHz)")

    # Locate peak values
    peak = np.argmax(ypow0)
    ax.plot(xf[peak], ypow0[peak], "ro")
    peak = np.argmax(ypow1)
    ax.plot(xf[peak], ypow1[peak], "ro")

    # add legend
    ax.legend()

##
# Example run code
##
#ypow0 = np.zeros(1024, dtype='float')
#ypow1 = np.zeros(1024, dtype='float')

default_formatter = ticker.ScalarFormatter()
@ticker.FuncFormatter
def sample_formatter(x, pos):
    return default_formatter.format_data_short(x*250+1040).strip()

def plot_time(data):
    fig, (ax_t, ax_f) = plt.subplots(2, 1)

    ax_t.plot((np.arange(2048)-1040)/250, data[:, 0], linewidth=1, label='Chan A')
    ax_t.plot((np.arange(2048)-1040)/250, data[:, 1], linewidth=1, label='Chan B')
    ax_t.set_ylabel('adc value')

    # fake, for the legend
    ax_t.axvspan(0, 0, alpha=0.5, linewidth=0, color='red', label='parity errors')
    for i in range(len(data)):
        if data[i, 2] != 0 or data[i,3] != 0:
            ax_t.axvspan((i-0.5-1040)/250, (i+0.5-1040)/250, alpha=0.5, linewidth=0, color='red')
    
    ax_t.set_xlabel('time (us)')
    ax2 = ax_t.twiny()
    #ax2.xaxis.set_ticks_position('bottom') 
    #ax2.xaxis.set_label_position('bottom')
    #ax2.spines['bottom'].set_position(('outward', 36))
    ax2.set_xlabel('time (samples)')
    ax2.set_xlim(ax_t.get_xlim())
    ax2.xaxis.set_major_formatter(sample_formatter)
    ax2.xaxis.set_minor_locator(ticker.AutoMinorLocator())

    # FFT
    xf, ypow = fft_from_samples(data[:, 0])
    ax_f.plot(xf, ypow)
    xf, ypow = fft_from_samples(data[:, 1])
    ax_f.plot(xf, ypow)

    ax_f.set_ylabel('power (dBm)')
    ax_f.set_xlabel('freq (MHz)')
    
    ax_t.legend()
    ax_f.legend()
    fig.tight_layout()
    
 

##
# Some helpers
##
def get_next(): 
    trigger() 
    return read_buffer() 

    
if __name__=="__main__":
    ##
    # Open serial connection
    open_serial()
    ##
    # Fix plotting in interactive mode...
    if in_ipython():
        plt.ion()

    for i in range(0, averages):
        trigger()

        # after the trigger is received we have to wait for:
        # * the second half of the buffer to fill (1024 samples at 250MHz)
        # * the transfer to the machxo to complete (2048 samples, 13 bits each, channels parallel at 60MHz)
        # this is under 0.5 ms so the overhead in driver + os + python is probably already much more.
        # the transfer automatically starts after the buffer is filled.
        time.sleep(2048*13/60e6+1024/250e6) 
        data = read_buffer()
        plot_time(data)

    ##
    # Show results
    plt.show()

