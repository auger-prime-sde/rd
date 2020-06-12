#!/bin/env/python3

import numpy as np
import matplotlib.pyplot as plt
import json

def sample_decode(x):
    x = x >> 1 # strip parity
    if x > 2048:
        return 4096-x
    else:
        return x
    
    

def get_data(filename):
    with open(filename) as f:
        data = json.load(f)
        data_ns = [int(x['adc_rd0']) for x in data]
        data_ew = [int(x['adc_rd1']) for x in data]
        return (data_ns, data_ew)
        


    
def test_triangle():
    for parity in ['even', 'odd']:
        for i in range(1, 100):
            data = get_data('trace_{}_{}.json'.format(parity, i))[0]
            diffs = [a-b for (a,b) in zip(data[1:], data[:-1])]
            print('{} trace {}:'.format(parity, i), end='')
            if abs(min(diffs)) == 1 and abs(max(diffs))==1:
                print('OK')
            else:
                print('FAIL')
                break

NUMTRACES = 100
fig, ax = plt.subplots()
for i in range(NUMTRACES):
    data_ns = get_data('trace_{}.json'.format(i))[0]
    data_ew = get_data('trace_{}.json'.format(i))[1]
    #trig_ns = [int(bin(sample_decode(x))[-1]) for x in data_ns]
    #trig_ew = [int(bin(sample_decode(x))[-1]) for x in data_ew]
    trig_ns = [sample_decode(x) % 2 for x in data_ns]
    trig_ew = [sample_decode(x) % 2 for x in data_ew]
    # zip and flatten:
    #ax.plot(trig_ns, '.')
    #ax.plot(np.arange(2048)-0.5, trig_ew, '.')
    trig = [x + 1.2*i for t in zip(trig_ew, trig_ns) for x in t]
    ax.plot(np.arange(4096)/2, trig, '-', linewidth=1, color='gray', drawstyle='steps')
    
ax.set_xlim(1024-4, 1024+4)
plt.tight_layout()
plt.show()

# TODO:
# make plot of jitter
# plot trigger on trac

# update uub bitfile?

# test decimating firmware
# 
