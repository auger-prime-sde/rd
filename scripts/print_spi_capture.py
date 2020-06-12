import numpy as np
import matplotlib.pyplot as plt

def bits_to_signed(bits):
    # cut to 12 bits in case there is parity or trigger info
    bits = bits[-12:]
    # bits to int
    unsigned = np.sum(bits * [2**(11-i) for i in range(12)])
    # decode 2's complement
    signed = unsigned if unsigned < 2048 else unsigned - 4096
    return signed
    

def get_trace(f):
    with open(f, "rb") as f:
        # Read the whole file at once
        data = f.read()
    
        data = np.frombuffer(data, np.uint8)
        data = np.unpackbits(data)
        trace_length = int(len(data) / (2*13))
        data = data.reshape([2 * trace_length, 13])

        tracedata = data[:,12] + data[:,11] * 2 + data[:,10] * 4 + data[:,9] * 8 + data[:,8] * 16 + data[:,7] * 32 + data[:,6] * 64 + data[:,5] * 128 + data[:,4] * 256 + data[:,3] * 512 + data[:,2] * 1024 + data[:,1] * 2048

        tracedata = np.array([x if x < 2048 else x - 4096 for x in tracedata])

        tracedata = tracedata.reshape([trace_length, 2])
        #data  = data.reshape([trace_length, 2, 13])
        tracedata = tracedata.transpose()
        return tracedata


 trace = get_trace('spi_trace_1.bin')
 plt.plot(trace[0])
 plt.plot(trace[1])
 plt.show()
 
#print("traces:")
#for i in range(trace_length):
#    print('{:05d}: {: 5d} {: 5d} ({} {})'.format(i, tracedata[0, i], tracedata[1, i], data[i][0], data[i][1]))


