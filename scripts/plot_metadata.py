#!/bin/env python3
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
plt.ion()

filename = '/home/themba/temp/rd_metadata_2020-06-02 10:57:41.txt'
filename = "rd_metadata_2.txt"

with open(filename) as f:
    lines = np.array(f.readlines())
#with open('rd_metadata_lab.txt') as f:
#    lines = np.array(f.readlines())


lines = lines.reshape([-1, 6])
ts   = np.array([int(x) for x in lines[:,0]])
temp = np.array([float(x.split()[1]) for x in lines[:,1]])
Ins  = np.array([float(x.split()[3]) for x in lines[:,2]])
Vns  = np.array([float(x.split()[3]) for x in lines[:,3]])
Iew  = np.array([float(x.split()[3]) for x in lines[:,4]])
Vew  = np.array([float(x.split()[3]) for x in lines[:,5]])

dT = list(map(lambda x: x[0]-x[1], zip(temp[1:],temp[:-1])))
dT.append(0)

df = pd.DataFrame({
    'Time': pd.to_datetime(ts*1e9),
    'dT': dT,
    'Temperature': temp,
    'Current_NS': Ins,
    'Voltage_NS': Vns,
    'Current_EW': Iew,
    'Voltage_EW': Vew
})


df.plot(x='Time', style='.')
