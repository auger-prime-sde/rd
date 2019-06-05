#!/usr/bin/env python3

import serial
import time
import numpy as np
import matplotlib.pyplot as plt
import scipy.signal as sig
from pprint import pprint
import sys
import json
import socket

pprint(sys.argv)
do_capture = len(sys.argv) < 2

## Number of FFTs to average
averages = 1

dev          = serial.Serial()
dev.port     = '/dev/ttyUSB1'
dev.baudrate = 115200
dev.timeout  = 1

scpi = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
scpi.connect(("131.174.192.59", 5025))

if do_capture:
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
    
    
def parity_from_int(i):
    bits = bin(i)[2:].rjust(13, '0') # make sure we get exactly 13 bits
    numones = len([x for x in bits if x=='1'])
    return numones % 2
    
    
def val_from_int(i):
    bits = bin(i)[2:].rjust(13, '0') # make sure we get exactly 13 bits
    #numones = len([x for x in bits if x=='1'])
    #if (numones % 2) == 0:
    #    print("parity mismatch!")
    
    #bits = bits[::-1] # reverse bit order
    bits = bits[:-1] # cut parity bit
    # val_unsigned = int(bin(i)[2:][-12:],2) # take the last 12 bits
    #val_unsigned = i & (2**12-1)
    val_unsigned = int(bits , 2)
    #val_unsigned = i >> 1
    if val_unsigned > 2047:
        return val_unsigned - 4096
    else:
        return val_unsigned

def int_from_val(val):
    if val < 0:
        val = val + 4096
    numones = len([x for x in bin(val)[2:] if x=='1'])
    parity  = (1+numones) % 2
    return val + (parity << 12)
    
    

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

def read_samples_from_file(fname):
    with open(fname) as f:
        data = json.load(f)

        par0 = sum([parity_from_int(int(x['adc_rd0'])) for x in data])
        par1 = sum([parity_from_int(int(x['adc_rd1'])) for x in data])
        par0 = len(data) - par0
        par1 = len(data) - par1
        
        for i in range(len(data)):
            x = data[i]
            x0 = int(x['adc_rd0'])
            x1 = int(x['adc_rd1'])
            
            if parity_from_int(x0) != 1:
                print("bad parity in channel {} sample {}:\t{}\t{}".format(0, i, x0, bin(x0)))
            if parity_from_int(x1) != 1:
                print("bad parity in channel {} sample {}:\t{}\t{}".format(1, i, x1, bin(x1)))
        
        print("parity check errors: {} {}".format(par0, par1))
        
        rd1 = [val_from_int(int(x['adc_rd0'])) for x in data]
        rd2 = [val_from_int(int(x['adc_rd1'])) for x in data]
        pmt0 = [int(x['adc0']) for x in data]
        pmt1 = [int(x['adc1']) for x in data]
        
        return (rd1, rd2, pmt0, pmt1)
        
        
def plot_timeseries(data, labels=('RD0', 'RD1', 'PMT0', 'PMT1'), samprate = (250.0,250.0, 120.0, 120.0)):
    for i, seriesdata in enumerate(data):
        y = np.asarray(seriesdata) / 2048.0
        N = len(y)
        T = 1.0/samprate[i]
        x = np.linspace(0.0, N*T, N)
        line, = plt.plot(x, y, label=labels[i], linewidth=1)
    plt.legend()
        
        



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

    #fix,ax = plt.subplots()
    #line = (ax.plot(x,y))[0]
    #line.set_marker("o")
    #line.set_markersize(3)
    #ax.set_xlabel("time (us)")
    #ax.set_ylabel("V")
  
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
    ax.set_ylim(-100,15)
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
    if do_capture:
        time.sleep(0.2)
        dev.reset_input_buffer()
        trigger()
        time.sleep(0.1)
        start_transfer()
        time.sleep(0.1)
    
    if len(sys.argv) > 1:
        # read from file
        (ch1, ch2, pmt1, pmt2) = read_samples_from_file(sys.argv[1])
    else:
        (ch1, ch2) = read_samples()
        #with open("test.json", "w+") as f:
        #    jsondata = [{"adc0": str(int_from_val(ch1[i])), "adc1": str(int_from_val(ch2[i]))} for i in range(2048)]
        #    json.dump(jsondata, f)
            
    #pprint(ch1)
    #pprint([(s) for s in ch2])
    (xf, ypow_new) = fft_from_samples(ch2)
    #if do_capture:
    #    plot_timeseries((ch1, ch2))
    #else:
    #    plot_timeseries((ch1, ch2, pmt1, pmt2))
    #ypow += ypow_new
    print_fft(xf, ypow_new)
    #plt.show()

    # power cycle
    scpi.send(b"OUTPUT:MASTER:STATE OFF\n")
    time.sleep(1)
    scpi.send(b"OUTPUT:MASTER:STATE ON\n")
    time.sleep(1)
    

#ypow = ypow / averages

#print_fft(xf, ypow)
#print_fft(xf, xt)

##
# Fix plotting in interactive mode...
if in_ipython():
    plt.ion()

##
# Show results
plt.show()


