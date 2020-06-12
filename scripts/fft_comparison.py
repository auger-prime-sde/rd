#!/bin/env python3
import numpy as np
from math import floor, sqrt
from pprint import pprint

LOG_FFT_LEN = 5
ICPX_WIDTH = 18
FFT_LEN = 2 ** LOG_FFT_LEN
scale = 2 ** (ICPX_WIDTH - 2) / FFT_LEN * 2
# scale components:
# (2**ICPX_WIDTH-2) because ICPX_WIDTH bits are used to represent a signed int
# FFT_LEN because the fft_engine normalizes
# 2 because this fft implementation somehow assumes that full scale means [-2, 2) and not [-1, 1)


def gen_triangle(start, direction, bits, offset):
    x = start - offset
    d = direction
    while True:
        cur = x + offset
        yield cur
        x = x + d
        if x == 2**(bits-1)-2:   # highest value is 2, 6, 14, etc. 
            d = -1
        if x == - (2**(bits-1)): # lowest value is -4, -8, -16 etc.
            d = 1


            
def gen_datain(filename):
    with open(filename) as f:
        for line in f:
            r = [float(token) for token in line.split()]
            yield (r[0] + r[1] * 1j) * scale * 2
            

t_gen = gen_triangle(90, -1, 5, 100)
t = [next(t_gen) for _ in range(2 * FFT_LEN)]
fft_in = [x[0]+1j*x[1] for x in np.array(t).reshape([32,2])]


def write_data_in(data):
    with open('data_in.txt', 'w') as f:
        for d in data:
            f.write('{:f} {:f}\n'.format(d.real / 2 ** (ICPX_WIDTH-2), d.imag / 2 ** (ICPX_WIDTH-2)))


#t_gen = gen_datain('/home/themba/synced/auger-radio-extension/rtl/housekeeping/calibration/versatile_fft/trunk/single_unit/data_in.txt')
#fft_in = [next(t_gen) for _ in range(FFT_LEN)]




fft_out = np.fft.fft([x / scale for x in fft_in]) * scale / FFT_LEN# / sqrt(FFT_LEN) * sqrt(2)

int_out = np.array([[floor(c.real), floor(c.imag)] for c in fft_out])


