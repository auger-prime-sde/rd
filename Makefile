.PHONY: settable_counter_tb clean wave.vcd all data_buffer_tb simple_counter_tb

all: data_buffer_tb settable_counter_tb simple_counter_tb

settable_counter_tb: rtl/settable_counter.vhd test/settable_counter_tb.vhd
	ghdl -a rtl/settable_counter.vhd
	ghdl -a test/settable_counter_tb.vhd
	ghdl -e settable_counter_tb
	ghdl -r settable_counter_tb --assert-level=warning

simple_counter_tb: rtl/simple_counter.vhd test/simple_counter_tb.vhd
	ghdl -a rtl/simple_counter.vhd
	ghdl -a test/simple_counter_tb.vhd
	ghdl -e simple_counter_tb
	ghdl -r simple_counter_tb --assert-level=warning

data_buffer_tb: rtl/data_buffer.vhd test/data_buffer_tb.vhd
	ghdl -a rtl/data_buffer.vhd
	ghdl -a test/data_buffer_tb.vhd
	ghdl -e data_buffer_tb
	## Disable IEEE warnings as RAM lookup operation gives problems during initialization
	ghdl -r data_buffer_tb --assert-level=warning --ieee-asserts=disable

wave.vcd:
	ghdl -r settable_counter_tb --vcd=wave.vcd

clean:
	rm -f work-obj93.cf
