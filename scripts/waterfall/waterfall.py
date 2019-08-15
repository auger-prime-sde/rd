#!/bin/env python3

import numpy as np
import glob
import os
import sys
import datetime
import time
import matplotlib
import matplotlib.pyplot as plt
import concurrent.futures
import scipy.ndimage.morphology

# list all data files
filenames = glob.glob('ffts/*.npy')
# sort
filenames.sort()
# for testing it's easier to chop a few
#filenames = filenames[:6000]
#filenames = filenames[1700:1800]

N = 2048
T = 1.0 / 250.0
x = np.linspace(0.0, N*T, N)
xf = np.linspace(0.0, 1.0/(2.0*T), int(N/2))

avgperiod = 60*30 # 30 minutes
starttime = datetime.datetime.strptime(filenames[0][5:-4], '%Y-%m-%d-%H:%M:%S')
stoptime  = datetime.datetime.strptime(filenames[-1][5:-4], '%Y-%m-%d-%H:%M:%S')

y = np.arange(starttime.timestamp(), stoptime.timestamp(), avgperiod)
ydates = [datetime.datetime.fromtimestamp(ts) for ts in y]

C = np.zeros((len(y), len(xf)))
lens = np.zeros(len(y))

print("number of times: ",len(y))


def process_sum(inp):
    i = inp[0]
    t = inp[1]
    sums = np.zeros(len(xf))
    count = 0
    for f in filenames:
        filetime = datetime.datetime.strptime(f[5:-4], '%Y-%m-%d-%H:%M:%S').timestamp()
        if filetime >= t and filetime < t + avgperiod:
            fftpair = np.load(f)
            sums += fftpair[0]
            count += 1
    if count > 0:
        sums /= count
    elif sum([1 for x in sums if x != 0]) > 0:
        print("Warning: zero ffts summed to a non-zero total")
    return i, t, sums


with concurrent.futures.ProcessPoolExecutor() as executor:
    for i,t,sums in executor.map(process_sum, enumerate(y)):
        print(i, t)
        C[i] = sums

np.save('C.npy', C)

E = scipy.ndimage.morphology.grey_erosion(C, (1, 11))
            
fig = plt.figure(figsize=(16,9), dpi=120)
ax  = plt.gca()
#plt.xlim(0,90)
ax.set_ylabel("time")
ax.set_xlabel("frequency (MHz)")
#ax.pcolor(ydates, xf, np.transpose(C))
ax.pcolor(xf[40:700], ydates, E[:,40:700])
#plt.gcf().autofmt_xdate()
fmt = matplotlib.dates.DateFormatter('%Y-%m-%d %H:%M')
ax.yaxis.set_major_formatter(fmt)

fig.tight_layout()

plt.savefig("waterfall.svg")
plt.savefig("waterfall.png")

    

#xf = np.append(xf, [xf[-1]+xf[1]-xf[0]])
#y = np.append(y, [y[-1]+avgperiod]) # add a closing timestamp




