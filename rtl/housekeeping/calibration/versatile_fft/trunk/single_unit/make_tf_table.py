#!/bin/env python3
import numpy as np
from math import pi, sin, cos

LOG2_FFT_LEN = 5
FFT_LEN = 2 ** LOG2_FFT_LEN
ICPX_WIDTH = 12

tf = []
for i in range(int(FFT_LEN / 2)):
    x = -i * pi * 2 / FFT_LEN
    c = cos(x) + 1j * sin(x)
    d = c * (2 ** (ICPX_WIDTH - 2))
    tf.append(d)

print('constant tf_table : T_TF_TABLE := (')
for x in tf:
    print('(Re => to_signed({}, {}), Im => to_signed({}, {})),'.format(round(x.real), ICPX_WIDTH, round(x.imag), ICPX_WIDTH))
print(');')

    
