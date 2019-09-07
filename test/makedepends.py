#!/bin/env python3
import sys
import re
from os import path

#print(sys.argv)
#sys.exit(0)

# check invocation
if len(sys.argv) != 3:
    print("Usage: {} <src file> <depfile>".format(sys.argv[0]))
    sys.exit(-1)


# extract unit name
sourcefilename = sys.argv[1]
depfilename    = sys.argv[2]
modname        = path.basename(depfilename)[:-2]

    
# prep regex
regex_dep = re.compile("\\s*component\\s+(\\S+)\\s+is\\s*")
regex_lib = re.compile("\\s*use\\s+work\\.(\\S+)\\.all;\\s*")
# open files and iterate over lines
dependencies = set()
libraries = set()
for line in open(sourcefilename):
    match = regex_dep.match(line)
    if match:
        dependencies.add(match.group(1))
    match = regex_lib.match(line)
    if match:
        libraries.add(match.group(1))

#print("identified dependencies for {}: {}".format(modname, dependencies))
#print("identified libraries for {}: {}".format(modname, libraries))

# print output to .d file
with open(depfilename, 'w') as outf: 
    outf.write("{}: output/{}.o {}\n".format(modname, modname, " ".join(['output/'+x+'.o' for x in dependencies])))
    outf.write("output/{}.o: {}\n".format(modname, " ".join(['output/'+x+'.o' for x in libraries.union(dependencies)])))
    #outf.write("output/{}.o: {}\n".format(modname, " ".join(['output/'+x+'.o' for x in libraries])))



