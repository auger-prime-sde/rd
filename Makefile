.PHONY: settable_counter_tb clean wave.vcd all data_buffer_tb simple_counter_tb uart_tb uart_expander_tb

all: data_buffer_tb settable_counter_tb simple_counter_tb uart_tb uart_expander_tb

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

uart_tb: rtl/uart.vhd test/uart_tb.vhd
	ghdl -a rtl/uart.vhd
	ghdl -a test/uart_tb.vhd
	ghdl -e uart_tb
	ghdl -r uart_tb --assert-level=warning

uart_expander_tb: rtl/uart_expander.vhd test/uart_expander_tb.vhd
	ghdl -a rtl/uart_expander.vhd
	ghdl -a test/uart_expander_tb.vhd
	ghdl -e uart_expander_tb
	ghdl -r uart_expander_tb --assert-level=warning

wave.vcd:
	ghdl -r settable_counter_tb --vcd=wave.vcd

uart_expander.vcd: uart_expander_tb
	ghdl -r uart_expander_tb --vcd=uart_expander.vcd

uart.vcd: uart_tb
	ghdl -r uart_tb --vcd=uart.vcd

clean:
	rm -f work-obj93.cf uart.vcd
