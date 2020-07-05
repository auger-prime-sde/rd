#!/bin/env python3
import numpy as np
from math import pi, floor, ceil, cos, sin, sqrt
from cmath import exp

#####################
## this sctipt is for manually verifying the result of my fft
## I'm comparing both the real fft from numpy.fft.rfft on 64 reals and the
## result of a procedure that merges/unmerges the 64 reals into a 32 bin
## complex fft and then "unfudges" it afterwards(like it's implemented on the
## fpga) to the trace from the fpga/ghdl. The latter is not visible in this
## script.

# helper to round both parts of a complex number
cplx_round = np.vectorize(lambda x: round(x.real) + 1j * round(x.imag))



#########################
## Common to both ways:
## generate sine wave
## apply window
## rounding to ints
DATA_LEN = 64
FFT_LEN  = DATA_LEN // 2

xs = np.arange(DATA_LEN)

# generate a sine wave as input with amplitude 0.3 and freq 10 MHz sampled at 250 MHz
# discretized to 12 bits full scale representing [-2, 2) range. 
# 20 offset is because in this test the first 20 are considered over the thres in ghdl
sin = np.sin(2.0 * pi * (xs+20) * 10 / 250) * 0.3 * 2 ** 10
sin = np.array([int(round(x)) for x in sin]) # make ints

# generate window
# 18 bits full scale representing the  range [-1,1)
win1 = np.array([0.5 - 0.5 * cos(2.0 * pi * i / (DATA_LEN-1)) for i in xs])
win2 = np.array([ 0.35875 \
                - 0.48829 * np.cos(      2.0 * pi * i / DATA_LEN) \
                + 0.14128 * np.cos(2.0 * 2.0 * pi * i / DATA_LEN) \
                - 0.01168 * np.cos(3.0 * 2.0 * pi * i / DATA_LEN) \
    for i in xs])
win3 = np.array([ 0.27105140069342 \
                - 0.43329793923448 * np.cos(      2.0 * pi * i / (DATA_LEN-1)) \
                + 0.21812299954311 * np.cos(2.0 * 2.0 * pi * i / (DATA_LEN-1)) \
                - 0.06592544638803 * np.cos(3.0 * 2.0 * pi * i / (DATA_LEN-1)) \
                + 0.01081174209837 * np.cos(4.0 * 2.0 * pi * i / (DATA_LEN-1)) \
                - 0.00077658482522 * np.cos(5.0 * 2.0 * pi * i / (DATA_LEN-1)) \
                + 0.00001388721735 * np.cos(6.0 * 2.0 * pi * i / (DATA_LEN-1)) \
    for i in xs])


win1 = np.array([int(round(x * 2 ** 17)) for x in win1]) # make ints
win2 = np.array([int(round(x * 2 ** 17)) for x in win2]) # make ints
win3 = np.array([int(round(x * 2 ** 17)) for x in win3]) # make ints



# generate the input signal
# We shift by 12 because after the multiplication we have 12+18 = 30 bits
# we discard the lower 12 to get to 18 bits representation again. The full scale
# range is [-2,2) again, as intended by the fft engine implementation.
# this is the integer signal going into both fft's
sig = (sin * win3) >> 12

# calculate power in signal
total_power_0 = sum(sig * sig)


###########################
## Method 1: calculate the DFT of the 64 reals directly
# this is what the result should look like
# normalize by sqrt(N) to preserve total power
fft = np.fft.rfft(sig) / sqrt(FFT_LEN)
#fft = np.array([int(round(x)) for x in fft])

pow1 = np.array([x.imag * x.imag + x.real * x.real for x in fft])
pow1 = np.array([int(round(x)) for x in pow1])
total_power_1 = sum(pow1)

def power(X):
    return sum([x.real * x.real + x.imag * x.imag for x in X])

#####################
## Method 2: merge/unmerge like in the fpga implementation
# This mimicks the calculation and should match the output of the method above

# reshape the 64 reals to 32 complex numbers
inp = [x[0] + 1j*x[1] for x in np.reshape(sig, (FFT_LEN,2))]

# do the 32 bin fft, normalize, and round
# note that at this point power is normalized
# so power(outp) would differ a factor FFT_LEN with power(inp)
outp = np.fft.fft(inp) / FFT_LEN
outp = cplx_round(outp)

# we need the fudge factors to unmerge the 32 complex fft into the first half of a complex 64 bin fft
# on an 18 bit scale from [-2, 2). Note that I have included the -i factor
# note that the length is FFT_LEN+1 because we need the center bin later
fudge = np.array([-1j * exp(-1j * i * 2 * pi / DATA_LEN) for i in range(FFT_LEN + 1)]) * 2 ** 16
fudge = cplx_round(fudge)

# prep the small fft output
a = np.append(outp, outp[0])
b = np.conj(np.flip(a))
# no rounding needed

Xk_sum  = cplx_round(a + b)
Xk_diff = cplx_round(a - b)
Xk_left = cplx_round(Xk_sum / 2)
Xk_diff2 = cplx_round(Xk_diff / 2)
Xk_right = cplx_round(Xk_diff2 * fudge / 2 ** 16)
Xk = cplx_round(Xk_left + Xk_right)

# unmerging of the fft
#Xk = (a + b) / 2 + (fudge * (a - b)/2) / 2**16


pow2 = np.array([x.imag * x.imag + x.real * x.real for x in Xk])
pow2 = np.array([int(round(x)) for x in pow2])



### usefull for plotting multiple axes
def align_yaxis(ax1, v1, ax2, v2): 
    """adjust ax2 ylimit so that v2 in ax2 is aligned to v1 in ax1""" 
    _, y1 = ax1.transData.transform((0, v1)) 
    _, y2 = ax2.transData.transform((0, v2)) 
    inv = ax2.transData.inverted() 
    _, dy = inv.transform((0, 0)) - inv.transform((0, y1-y2)) 
    miny, maxy = ax2.get_ylim() 
    ax2.set_ylim(miny+dy, maxy+dy) 
          

