.PHONY: clean wave.vcd all data_buffer_tb simple_counter_tb uart_tb uart_expander_tb write_controller_tb readout_controller_tb

#GHDL_OPTS = --ieee=synopsys -fexplicit -Plattice/ecp5u/v93

all: data_buffer_tb simple_counter_tb uart_tb uart_expander_tb write_controller_tb readout_controller_tb


clock_divider_tb: rtl/clock_divider.vhd test/clock_divider_tb.vhd
	ghdl -a $(GHDL_OPTS)  rtl/clock_divider.vhd
	ghdl -a $(GHDL_OPTS)  test/clock_divider_tb.vhd
	ghdl -e $(GHDL_OPTS)  clock_divider_tb
	ghdl -r $(GHDL_OPTS) clock_divider_tb --assert-level=warning

simple_counter_tb: rtl/simple_counter.vhd test/simple_counter_tb.vhd
	ghdl -a $(GHDL_OPTS)  rtl/simple_counter.vhd
	ghdl -a $(GHDL_OPTS)  test/simple_counter_tb.vhd
	ghdl -e $(GHDL_OPTS)  simple_counter_tb
	ghdl -r $(GHDL_OPTS) simple_counter_tb --assert-level=warning

data_buffer_tb: rtl/data_buffer.vhd test/data_buffer_tb.vhd
	ghdl -a $(GHDL_OPTS)  rtl/data_buffer.vhd
	ghdl -a $(GHDL_OPTS)  test/data_buffer_tb.vhd
	ghdl -e $(GHDL_OPTS)  data_buffer_tb
	# Disable IEEE warnings as RAM lookup operation gives problems during initialization
	ghdl -r $(GHDL_OPTS) data_buffer_tb --assert-level=warning --ieee-asserts=disable

uart_tb: rtl/uart.vhd test/uart_tb.vhd
	ghdl -a $(GHDL_OPTS)  rtl/uart.vhd
	ghdl -a $(GHDL_OPTS)  test/uart_tb.vhd
	ghdl -e $(GHDL_OPTS)  uart_tb
	ghdl -r $(GHDL_OPTS) uart_tb --assert-level=warning

uart_expander_tb: rtl/uart_expander.vhd test/uart_expander_tb.vhd
	ghdl -a $(GHDL_OPTS)  rtl/uart_expander.vhd
	ghdl -a $(GHDL_OPTS)  test/uart_expander_tb.vhd
	ghdl -e $(GHDL_OPTS)  uart_expander_tb
	ghdl -r $(GHDL_OPTS) uart_expander_tb --assert-level=warning

write_controller_tb: rtl/write_controller.vhd test/write_controller_tb.vhd
	ghdl -a $(GHDL_OPTS)  rtl/write_controller.vhd
	ghdl -a $(GHDL_OPTS)  rtl/simple_counter.vhd
	ghdl -a $(GHDL_OPTS)  test/write_controller_tb.vhd
	ghdl -e $(GHDL_OPTS)  write_controller_tb
	ghdl -r $(GHDL_OPTS) write_controller_tb --assert-level=warning

readout_controller_tb: rtl/readout_controller.vhd test/readout_controller_tb.vhd
	ghdl -a $(GHDL_OPTS)  rtl/readout_controller.vhd
	ghdl -a $(GHDL_OPTS)  test/readout_controller_tb.vhd
	ghdl -e $(GHDL_OPTS)  readout_controller_tb
	ghdl -r $(GHDL_OPTS) readout_controller_tb --assert-level=warning




wave.vcd:
	ghdl -r settable_counter_tb --vcd=wave.vcd
uart_expander.vcd: uart_expander_tb
	ghdl -r uart_expander_tb --vcd=uart_expander.vcd
uart.vcd: uart_tb
	ghdl -r uart_tb --vcd=uart.vcd
readout_controller.vcd: readout_controller_tb
	ghdl -r readout_controller_tb --vcd=readout_controller.vcd




clean:
	rm -f *-obj93.cf *.vcd *.o
