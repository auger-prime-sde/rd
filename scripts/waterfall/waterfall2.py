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
from scipy.ndimage.morphology import grey_erosion

NUMAVG = 60
NUMSEEVE = 60
NUMERODE = 15

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

data = np.array([np.load(f) for f in filenames])
print("files loaded")

selection = data[:,0,:]

vmin = np.min(selection)
vmax = np.max(selection)

eroded = grey_erosion(selection, (1, NUMERODE))

print("erosion filter done")

def smoothing(arr):
    return np.convolve(arr, np.ones(NUMAVG)/NUMAVG, mode='valid')
smoothed = np.apply_along_axis(smoothing, 0, eroded)

print("smoothing filter done")

fig = plt.figure()
ax  = plt.gca()
ax.pcolor(selection[::NUMSEEVE], vmin=vmin, vmax=vmax)
fig.tight_layout()

fig = plt.figure()
ax  = plt.gca()
ax.pcolor(eroded[::NUMSEEVE], vmin=vmin, vmax=vmax)
fig.tight_layout()

fig = plt.figure()
ax  = plt.gca()
ax.pcolor(smoothed[::NUMSEEVE], vmin=vmin, vmax=vmax)
fig.tight_layout()

print("plots done")

