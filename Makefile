.PHONY: settable_counter_tb clean

settable_counter_tb: rtl/settable_counter.vhd test/settable_counter_tb.vhd
	ghdl -a rtl/settable_counter.vhd
	ghdl -a test/settable_counter_tb.vhd
	ghdl -r settable_counter_tb --assert-level=warning

wave.vcd:
	ghdl -r settable_counter_tb --vcd=wave.vcd

clean:
	rm -f work-obj93.cf
