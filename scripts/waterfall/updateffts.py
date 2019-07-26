#!/bin/env python3

import numpy as np
import glob
import os
import sys
import datetime
import time
import concurrent.futures

# useful to remember:
# rsync -auve "ssh -p 7722" "pi@localhost:data/*.npy" .
# ffmpeg -r 60 -start_number 681 -f image2 -s 1920x976 -i images/%06d.png test.mkv

FORMAT = '%Y-%m-%d-%H:%M:%S'


# some constants for later
N = 2048
T = 1.0 / 250.0
x = np.linspace(0.0, N*T, N)
xf = np.linspace(0.0, 1.0/(2.0*T), int(N/2))



##
# Compute the FFT of a sample sequence 
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



# list all data files
filenames = glob.glob('data/*.npy')
# sort
filenames = sorted(filenames)
# for testing it's easier to chop a few
#filenames = filenames[:3000]
# filenames = filenames[1700:1800]

def process_one(f):
    # skip the ones that are from experimenting in the lab out
    filetime = datetime.datetime.strptime(f[5:-4], FORMAT)
    if filetime < datetime.datetime(2019,7,18,18, 50, 00):
        return f

    # skip if already did an fft:
    fftfile = 'ffts/{}.npy'.format(datetime.datetime.strftime(filetime, FORMAT))
    if os.path.exists(fftfile):
        return f

    # skip if too small (happens if pi unsafely powered down)
    size = os.path.getsize(f)
    if size == 0:
        print("\nskipping empty file {}".format(f))
        return f

    # load data
    data = np.load(f)

    # skip if parity error
    if np.sum(data[2:4]) != 4096:
        print("\nparity mismatch in {}".format(f))
        return f

    # do the actual fft
    xf, fft1 = fft_from_samples(data[0], False)
    xf, fft2 = fft_from_samples(data[1], False)

    # save result
    np.save(fftfile, (fft1, fft2))
    return f

with concurrent.futures.ProcessPoolExecutor() as executor:
    for f in executor.map(process_one, filenames):
        print("\rProcessing: {}".format(f), end='')
print("\rProcessing: done                                    ")

    
        



