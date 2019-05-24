#!/usr/bin/env python3

import numpy as np
import matplotlib.pyplot as plt
import scipy.signal as sig
from pprint import pprint
import sys
import json

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
# Helper function for extracting data
##
def correct_sign(val):
    return int(val) - 4096 if int(val) > 2047 else int(val)

##
# Read rdsamples file from CDAS data and parse sample data
##
def read_samples_from_file(fname):
    data = np.loadtxt(fname, usecols=(1,2), converters={1: correct_sign, 2: correct_sign}, dtype=int)

    ch0 = data[:,0]
    ch1 = data[:,1]
    return (ch0, ch1)

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

#    fix,ax = plt.subplots()
#    line = (ax.plot(x,y))[0]
#    line.set_marker("o")
#    line.set_markersize(3)
#    ax.set_xlabel("time (us)")
#    ax.set_ylabel("V")
  
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
if len(sys.argv) == 1:
    print("Usage: {} input.rd-samples ...\n\nPlot average power spectrum over provided input data".format(sys.argv[0]))
    sys.exit(0)

# Average over all input files
ypow0 = np.zeros(1024, dtype='float')
ypow1 = np.zeros(1024, dtype='float')

for i in range(1,len(sys.argv)):
    print("Analyzing {}".format(sys.argv[i]))
    # read from file
    (ch0, ch1) = read_samples_from_file(sys.argv[i])

    (xf, ypow0_new) = fft_from_samples(ch0)
    (xf, ypow1_new) = fft_from_samples(ch1)

    ypow0 += ypow0_new
    ypow1 += ypow1_new

ypow0 /= len(sys.argv)-1
ypow1 /= len(sys.argv)-1

# Plot graph
print_fft(xf, ypow0, ypow1)

##
# Fix plotting in interactive mode...
if in_ipython():
    plt.ion()

##
# Show results
plt.show()

