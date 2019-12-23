#!/usr/bin/env python3

import serial
import time
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
#import scipy.signal as sig
#from pprint import pprint
#import sys
import platform

## Number of FFTs to average
averages = 1
dev      = None

def open_serial():
    global dev
    dev = serial.Serial()
    if platform.system() == 'Windows' :
        dev.port     = 'COM9'
    elif platform.system() == 'Darwin' :
        dev.port  = '/dev/tty.usbserial-14201'
    else:
        dev.port = '/dev/ttyUSB1'
    
    dev.baudrate = int(2.015e6)#115200#int(6.05e6)
    dev.timeout  = 1
    dev.open()
    dev.write("r".encode('utf-8'))

##
# Detect if we're running in interactive mode to avoid problems with matplotlib
##
def in_ipython():
    try:
        __IPYTHON__
    except NameError:
        return False
    else:
        return True

##
# Trigger the digitizer using the DTR line on the UART.  The DTR line is active low so writing a 0 here gives a 1 on the physical line.
##
def trigger():
    global dev
    dev.write("T".encode('utf-8'))
    dev.flush()

def dump_to_uart():
    global dev
    dev.reset_input_buffer()
    dev.write("d".encode('utf-8'))
    dev.flush()

  
##
# Read and decompose input bytes. Returns a numpy array with, for each sample number, two sample values, 2 parity checks and 2 trigger bits
##
def read_buffer():
    dump_to_uart()
    data = np.zeros((2048, 6)) # for each sample 2 channel values, 2 parity checks and 2 trigger bits
    for ch in range(2):
        for b in range(2048):
            raw = dev.read(2)
            val_unsigned = ((raw[0] & 0x7F) << 5) + (raw[1] >> 3)
            if val_unsigned > 2047:
                val_unsigned = val_unsigned - 4096
            bits = bin(raw[0]) + bin(raw[1] >> 2)
            numones = len([x for x in bits if x=='1'])
            data[b, 0+ch] = val_unsigned
            data[b, 2+ch] = 1 - (numones % 2)
            data[b, 4+ch] = raw[0] >> 7
            #print("ch{} sample {:4d}: raw: {:08b} {:08b} val: {:5d} {}".format(ch, b, raw[0], raw[1], val_unsigned, "parity ok" if numones % 2 == 1 else "Parity FAIL" ))
    return data




##
# Compute the FFT of a sample sequence and plot it using matplotlib.
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


def make_fft_plot(xf):
    global line1, line2, marker1, marker2, fig, background, ax, text
    # Start plotting things
    fig, ax = plt.subplots()
    line2, = ax.plot(xf, np.zeros(len(xf)), label='ch1')
    line1, = ax.plot(xf, np.zeros(len(xf)), label='ch0')
    ax.set_ylabel("power (dBm)")
    ax.set_xlabel("frequency (MHz)")
    ax.set_ylim(-110.0,10.0)
    text = ax.text(0, 0, "")

    # Locate peak values
    marker1, = ax.plot(0, 0, "ro")
    marker2, = ax.plot(0, 0, "ro")

    # add legend
    ax.legend()
    
t_prev = 0
def update_fft_plot(ypow0, ypow1):
    global line1, line2, marker1, marker2, fig, text, t_prev
    line1.set_ydata(ypow0)
    line2.set_ydata(ypow1)

    # Locate peak values
    peak = np.argmax(ypow0)
    marker1.set_xdata(xf[peak])
    marker1.set_ydata(ypow0[peak])
    peak = np.argmax(ypow1)
    marker2.set_xdata(xf[peak])
    marker2.set_ydata(ypow1[peak])

    t_this = time.time()
    tx = 'Mean Frame Rate:\n {fps:.3f}FPS'.format(fps= ((1) / (t_this - t_prev)))  
    text.set_text(tx)
    t_prev = t_this
    
    fig.canvas.draw()
    fig.canvas.flush_events()



def make_time_plot():
    global fig, errA, errB, chanA, chanB, trigStep, trigDots1, trigDots2
    # setup grid and axes
    grid = plt.GridSpec(5, 1, hspace=0.02, wspace=0.02)
    fig = plt.figure()
    #ax_main = fig.add_subplot(grid[:3, :])
    ax_main = plt.gca()
    ax_trig = ax_main.twinx()
    #ax_err = fig.add_subplot(grid[4,:])
    # configure main axis
    ax_main.set_ylabel('adc value')
    ax_main.set_ylim(-20, 20)
    chanA, = ax_main.plot([], linewidth=1, label='Chan A')
    chanB, = ax_main.plot([], linewidth=1, label='Chan B')
    
    # configure trig axis
    ax_trig._get_lines.prop_cycler = ax_main._get_lines.prop_cycler
    ax_trig.set_ylim(-0.1, 1.1)
    xtrig = np.arange(4096)/2
    ytrig = np.zeros(4096)
    trigStep, = ax_trig.step(xtrig, ytrig, linewidth=1, where='mid', label='trigger')
    trigDots1, = ax_trig.plot(np.arange(2048), np.zeros(2048), '.', label='trig level')
    trigDots2, = ax_trig.plot((np.arange(2048)+0.5), np.zeros(2048), '.', label='trig super-sample')

    # configure error axis
    #ax_err._get_lines.prop_cycler = ax_trig._get_lines.prop_cycler
    #errA, = ax_err.plot(np.arange(2048), [None for _ in range(2048)], label='parity errors Chan A')
    #errB, = ax_err.plot(np.arange(2048), [None for _ in range(2048)], label='parity errors Chan B')
    #ax_err.set_ylim(-0.1, 1.1)
    #ax_err.set_xlabel('time (us)')

    ax_main.legend()
    ax_trig.legend()
    #ax_err.legend()

def update_time_plot(data):
    # update channel values
    chanA.set_data(np.arange(2048), data[:,0])
    chanB.set_data(np.arange(2048), data[:,1])
    # update error plot
    #errA.set_data(np.arange(2048), data[:,2])
    #errB.set_data(np.arange(2048), data[:,3])
    # update trigger
    trigStep.set_ydata([x for t in zip(data[:,5], data[:,4]) for x in t])
    trigDots1.set_ydata(data[:,5])
    trigDots2.set_ydata(data[:,4])

##
# Example run code
##

## prepare empty plots
N = 2048
T = 1.0 / 250.0
x = np.linspace(0.0, N*T, N)
xf = np.linspace(0.0, 1.0/(2.0*T), int(N/2))
#make_fft_plot(xf)

plt.ion()
make_time_plot()

##
# Fix plotting in interactive mode...
#if in_ipython():
#plt.ion()

##
# Show results
#plt.show()



open_serial()
while True:
    trigger()
    data = read_buffer()
    update_time_plot(data)
    plt.show()
    plt.pause(0.05)

    

while False:
    ypow0 = np.zeros(1024, dtype='float')
    ypow1 = np.zeros(1024, dtype='float')

    start = time.time()
    ends = []
    for i in range(0, averages):
        #time.sleep(0.02)
        dev.reset_input_buffer()
        
        trigger()
        start_transfer()
        
        startread = time.time()
        (ch0, ch1) = read_samples()
        #print("read samples: {}".format(time.time()-startread))

        #pprint(ch1)
        #pprint([(s) for s in ch1])
        (xf, ypow0_new) = fft_from_samples(ch0, False)
        (xf, ypow1_new) = fft_from_samples(ch1, False)

        ypow0 += ypow0_new
        ypow1 += ypow1_new
        ends.append(time.time())

    #print("whole update routine {}".format(ends[0]-start))

    ypow0 /= averages
    ypow1 /= averages
    
    update_fft_plot(ypow0, ypow1)

