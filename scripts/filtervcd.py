#!/bin/env python3
import sys

bad_signals = []

with open(sys.argv[1], "r") as f:
	for line in f:
		if line.startswith("$var"):
			try:
				if int(line.split()[2]) != 1:
					bad_signals.append(line.split()[3])
					#print("bad signals is now: {}".format(bad_signals),file=sys.stderr)
					continue
			except:
				pass

		isbad = False
		for s in bad_signals:
			if line.strip().endswith(" "+s):
				isbad = True
				break
		if not isbad:
			print(line, end="")
