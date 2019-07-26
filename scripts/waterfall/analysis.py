#!/bin/env python3

import numpy as np
import glob
import os
import sys
import datetime
import time
import concurrent.futures
import matplotlib
import matplotlib.pyplot as plt
matplotlib.use('TkAgg') # 3.7s
#matplotlib.use('GTK3Agg') # 3.8s
#matplotlib.use('Qt4Agg') # 4.6s
#matplotlib.use('Qt5Agg') # 4.7s
#matplotlib.use('agg') # 3.9s


# useful to remember:
# rsync -auve "ssh -p 7722" "pi@localhost:data/*.npy" .
# ffmpeg -r 60 -start_number 681 -f image2 -s 1920x976 -i images/%06d.png test.mkv



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
filenames = glob.glob('*.npy')
# filter the ones that are from experimenting in the lab out
filenames = filter(lambda f: datetime.datetime.strptime(f[:-4], '%Y-%m-%d-%H:%M:%S')> datetime.datetime(2019,7,18,18, 38, 24), filenames)
# sort
filenames = sorted(filenames)
# for testing it's easier to chop a few
# filenames = filenames[:1000]
# filenames = filenames[1700:1800]

datetimes = []
samples = []
ffts = []


#for i,t in enumerate(filenames):
#    print(i,t)


############################
## Load all files into memory
for f in filenames:
    print("\rLoading: {}".format(f), end='')
    size = os.path.getsize(f)
    if size == 0:
        print("\nskipping empty file {}".format(f))
        continue
    data = np.load(f)
    if np.sum(data[2:4]) != 4096:
        print("\nparity mismatch in {}".format(f))
        continue

    datetimes.append(datetime.datetime.strptime(f[:-4], '%Y-%m-%d-%H:%M:%S'))
    samples.append(data[0:2])
print("\rLoading: done                                     ")


#################################
## Do all FFT's in parallel
def do_fft(data):
    print("\rFFT'ing: {}".format(data[0]), end='')
    fft1 = fft_from_samples(data[1][0], False)[1]
    fft2 = fft_from_samples(data[1][1], False)[1]
    return (fft1, fft2)

with concurrent.futures.ProcessPoolExecutor() as executor:
    for fftpair in executor.map(do_fft, zip(datetimes, samples)):
        ffts.append(fftpair)
print("\rFFT'ing: done                                    ")


###############################
## Do simple plots in parallel
def plot_initializer():
    global fig, ax, line1, line2, text
    print("Creating plotting context in process.")
    fig = plt.figure(figsize=(16,9), dpi=120)
    ax  = plt.gca()
    ax.set_ylabel("power (dBm)")
    ax.set_xlabel("frequency (MHz)")
    ax.set_ylim(-110.0 ,5.0)
    line1, = ax.plot(xf, np.zeros(len(xf)), label='ch0')
    line2, = ax.plot(xf, np.zeros(len(xf)), label='ch1')
    text   = ax.text(0, 0, 'text')
    ax.legend()
    fig.tight_layout()
        
def plot_worker(data):
    global line1, line2, text
    outputfilename = 'images/{:s}_{:06d}.png'.format(data[3], data[2])
    if os.path.exists(outputfilename):
        return data[1]
    line1.set_ydata(data[0][0])
    line2.set_ydata(data[0][1])
    text.set_text('{}'.format(data[1]))
    plt.savefig(outputfilename)
    return data[1]

with concurrent.futures.ProcessPoolExecutor(initializer=plot_initializer) as executor:
    for t in executor.map(plot_worker, zip(ffts, datetimes, range(len(datetimes)), np.repeat('simple', len(datetimes)))):
        print("\rPlotting: {}".format(t), end='')
print("\rPlotting: done                        ")



##################################3
## Do averaged plots
numaverages = 100
groups = []
i = 0
group_i = 0
total0 = np.zeros(1024, dtype='float')
total1 = np.zeros(1024, dtype='float')
for data,t in zip(ffts, datetimes):
    i += 1
    if (i % numaverages) == 0:
        group_i += 1
        groups.append(((total0/numaverages, total1/numaverages), t, group_i, 'avg{}'.format(numaverages)))
        total0 = np.zeros(1024, dtype='float')
        total1 = np.zeros(1024, dtype='float')
    total0 += data[0]
    total1 += data[1]

# each groups item is a 4-tuple with ffts, a datetime, a number and a label
with concurrent.futures.ProcessPoolExecutor(initializer=plot_initializer) as executor:
    for t in executor.map(plot_worker, groups):
        print("\rAveraged plots: {}".format(t), end='')
print("\rAveraged plots: done                        ")


#################################
## Averages per day
per_day_count = {}
per_day_total1 = {}
per_day_total2 = {}
for data,t in zip(ffts, datetimes):
    d = t.date()
    if d not in per_day_count:
        per_day_count[d]  = 0
        per_day_total1[d] = np.zeros(1024, dtype='float')
        per_day_total2[d] = np.zeros(1024, dtype='float')

    per_day_count[d] += 1
    per_day_total1[d] += data[0]
    per_day_total2[d] += data[1]

#print(per_day_count)
#print(per_day_total1)


groups = [((per_day_total1[t]/per_day_count[t], per_day_total2[t]/per_day_count[t]), t, i+1, 'daily') for i, t  in enumerate(per_day_count)]

with concurrent.futures.ProcessPoolExecutor(initializer=plot_initializer) as executor:
    for t in executor.map(plot_worker, groups):
        print("\rDaily plots: {}".format(t), end='')
print("\Daylyplots: done                        ")

        

