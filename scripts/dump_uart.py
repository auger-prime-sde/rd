#!/usr/bin/env python3

import serial
import time
import numpy as np
import matplotlib.pyplot as plt
import scipy.signal as sig

plt.ion()

dev          = serial.Serial()
dev.port     = '/dev/ttyUSB1'
dev.baudrate = 1000000
dev.timeout  = 1
dev.bytesize = 7
dev.dtr      = 1
dev.open()

def trigger():
    dev.dtr = 0
    #time.sleep(0.001)
    dev.dtr = 1

def val_from_raw(raw1, raw0):
  val_unsigned = (raw1 << 7) + raw0
  if val_unsigned > 2047:
    return val_unsigned - 4096
  else:
    return val_unsigned

def read_sample():
    time.sleep(2)
    dev.reset_input_buffer()
    trigger()
    ch1_data = []
    ch2_data = []

    for b in range(2048):
        raw = dev.read(4)
        #print(raw[2])
        #print(raw[3])
        #print(raw[2])
        #print(raw[3])
        #print("%04d: % 3d % 3d % 3d % 3d"%(b,raw[0], raw[1], raw[2], raw[3]))
        ch1 = val_from_raw(raw[1], raw[0])
        ch2 = val_from_raw(raw[3], raw[2])
        print("% 4d: % 4d % 4d"%(b, ch1,ch2))
        ch1_data.append(ch1)
        ch2_data.append(ch2)


    print("done")
    dev.timeout = 1
    junk = dev.read(10000)
    print("%d bytes remained in buffer after read"%len(junk))
    return (ch1_data, ch2_data)

def fft_from_samples(data):
    # Scale data to voltages
    y = np.asarray(data) / 2048. * 1.75/2.0;

    # Number of samplepoints
    N = len(y)
    # sample spacing
    T = 1.0 / 200.0
    x = np.linspace(0.0, N*T, N)
    xf = np.linspace(0.0, 1.0/(2.0*T), N/2)

    fig, ax = plt.subplots()
    ax.plot(x, y)

    # Apply windowing function (choose from hamming, hann, bartlett, blackman)
    # Compute FFT, default size = data size
    window = 'blackmanharris-7'
    if(window == 'blackmanharris-7'):
        w = np.zeros((N), dtype='float')
        for n in np.arange(0, N):
            w[n] = 0.27105140069342 - 0.43329793923448 * np.cos(   2.*np.pi*n/N) + 0.21812299954311 * np.cos(2.*2.*np.pi*n/N) - 0.06592544638803 * np.cos(3.*2.*np.pi*n/N) + 0.01081174209837 * np.cos(4.*2.*np.pi*n/N) - 0.00077658482522 * np.cos(5.*2.*np.pi*n/N) + 0.00001388721735 * np.cos(6.*2.*np.pi*n/N)

    # Coherent gain
    CPG = np.sum(w)/N
    CPGdB = -20*np.log10(CPG)
    
    # Compute FFT with windowing applied
    # Divide by N to compensate for FFT scaling
    yf = np.fft.fft(y*w) / N
    
    # Translate to power dBm in 50R, fold spectrum to single band, and convert into dB
    ypowl = 2*1000*np.abs(yf[:N//2])**2/50
    ypow = 10*np.log10(ypowl)
    
    # Locate peak value
    peak = np.argmax(ypow)
    
    # Start plotting things
    fig, ax = plt.subplots()
    ax.plot(xf, ypow+CPGdB)
    ax.plot(xf[peak], ypow[peak]+CPGdB, "ro")
    ax.set_ylabel("power (dBm)")
    ax.set_xlabel("frequency (MHz)")
    
    # Plot label with statistics for peak
    # Compute equivalent noise bandwidth for our window and determine SINAD to add to labels
    ENBW = N * np.sum(w**2)/np.sum(w)**2
    ENBWdB = 10*np.log10(ENBW)
    
    # Processing gain
    PGdB = 10*np.log10(2.0/N)
    
    print("GPG={3:.2f}dB, ENBW={0:.2f}dB, PG={1:.2f}dB, N={2}".format(ENBWdB, PGdB, N, CPGdB))
    peak_width=20
    
    NF = 10*np.log10(np.sum(ypowl[:peak-peak_width])+np.sum(ypowl[peak+peak_width:]))
    NFtrue = NF + CPGdB + PGdB - ENBWdB
    SINAD = ypow[peak]-NFtrue


(ch1, ch2) = read_sample()
fft_from_samples(ch1)
