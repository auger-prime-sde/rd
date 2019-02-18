.PHONY: clean

#GHDL_OPTS = --ieee=synopsys -fexplicit -Plattice/ecp5u/v93
GHDL_RUN_OPTS = --assert-level=warning --ieee-asserts=disable

all: data_buffer_tb simple_counter_tb write_controller_tb readout_controller_tb data_writer_tb flash_controller_tb housekeeping_tb

flash_controller_tb: rtl/flash/flash_controller.vhd test/flash_controller_tb.vhd
	ghdl -a $(GHDL_OPTS) $^
	ghdl -e $(GHDL_OPTS) $@
	ghdl -r $(GHDL_OPTS) $@ $(GHDL_RUN_OPTS)
housekeeping_tb: rtl/housekeeping/housekeeping.vhd test/housekeeping_tb.vhd
	ghdl -a $(GHDL_OPTS) $^
	ghdl -e $(GHDL_OPTS) $@
	ghdl -r $(GHDL_OPTS) $@ $(GHDL_RUN_OPTS)


%_tb: rtl/data_streamer/%.vhd test/%_tb.vhd
	ghdl -a $(GHDL_OPTS)  $^
	ghdl -e $(GHDL_OPTS)  $@
	ghdl -r $(GHDL_OPTS)  $@ $(GHDL_RUN_OPTS) 

wave.vcd:
	ghdl -r settable_counter_tb --vcd=wave.vcd
%.vcd: %_tb
	ghdl -r $(GHDL_OPTS) $^ --vcd=$@
%.ghw: %_tb
	ghdl -r $(GHDL_OPTS) $^ --wave=$@


clean:
	ghdl $(GHDL_OPTS) --clean
	rm -f *-obj93.cf *.vcd *.o *.ghw

