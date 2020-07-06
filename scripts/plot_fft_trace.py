#!/bin/env python3

import numpy as np
import matplotlib.pyplot as plt
import sys
import bitstring


##
# Read raw binary trace
##
def get_raw():
    bits = bitstring.Bits(open('raw_trace.bin'))
    bstr = bitstring.ConstBitStream(bits)
    ns = np.zeros(2048)
    ew = np.zeros(2048)
    for i in range(2048):
        bstr.read('int:1')
        ns[i] = bstr.read('int:12')
        bstr.read('int:1')
        ew[i] = bstr.read('int:12')
    return ns, ew
        
##
# Read fft ascii file output by RD
##
def get_fft():
    data = np.loadtxt('fft_trace.txt')
    ns,ew = data[:,0], data[:,1]
    return ns,ew

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
    xf = np.linspace(0.0, 1.0/(2.0*T), int(N/2))

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


#plt.ion()
fig, ax = plt.subplots()

##
# First, get the raw trace
##
raw_ns, raw_ew = get_raw()

# do the 'traditional' ff
xf, ypow_ns = fft_from_samples(raw_ns)
_ , ypow_ew = fft_from_samples(raw_ew)

# make the plots
ax.plot(xf, ypow_ns, label='fft from raw (NS)')
ax.plot(xf, ypow_ew, label='fft from raw (EW)')


##
# Second, the new pre-processed fft
##
fft_ns, fft_ew = get_fft()

# compute the coherent propagation gain of the embedded window
N = 2 * len(fft_ns)
w = np.zeros((N), dtype='float')

for n in np.arange(0, N):
    w[n] = 0.27105140069342 \
        - 0.43329793923448 * np.cos(   2.*np.pi*n/(N-1)) \
        + 0.21812299954311 * np.cos(2.*2.*np.pi*n/(N-1)) \
        - 0.06592544638803 * np.cos(3.*2.*np.pi*n/(N-1)) \
        + 0.01081174209837 * np.cos(4.*2.*np.pi*n/(N-1)) \
        - 0.00077658482522 * np.cos(5.*2.*np.pi*n/(N-1)) \
        + 0.00001388721735 * np.cos(6.*2.*np.pi*n/(N-1))
CPG = np.sum(w)/N
CPGdB = -20*np.log10(CPG)


fft_ns = 10 * np.log10(fft_ns/100) -CPGdB
fft_ew = 10 * np.log10(fft_ew/100) -CPGdB
ax.plot(xf, fft_ns, label='RD fft (NS) 100-avg')
ax.plot(xf, fft_ew, label='RD fft (EW) 100-avg')





fig.tight_layout()
ax.legend()
