#!/bin/env python3

import numpy as np
import matplotlib.pyplot as plt
import sys

raw = np.loadtxt('fft_trace.txt')

#plt.ion()
fig, ax = plt.subplots()

N = len(raw) # number of fft bins
binwidth = 125e6 / N

xf = np.arange(N) * binwidth

ax.plot(xf, raw[:,0], label='NS')
ax.plot(xf, raw[:,1], label='EW')
ax.legend()
