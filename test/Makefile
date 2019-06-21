.PHONY: clean

#GHDL_OPTS = --ieee=synopsys -fexplicit -Plattice/ecp5u/v93
GHDL_OPTS = --workdir=output
GHDL_RUN_OPTS = --assert-level=warning --ieee-asserts=disable

all: data_streamer housekeeping

data_streamer: data_buffer_tb simple_counter_tb write_controller_tb readout_controller_tb data_writer_tb
housekeeping: spi_demux_tb spi_decoder_tb digitaloutput_tb bootsequence_tb

# define some order constraints
write_controller_tb : | simple_counter_tb data_buffer_tb


%_tb: ../rtl/%.vhd %_tb.vhd
	ghdl -a $(GHDL_OPTS) $^
	ghdl -e $(GHDL_OPTS) $@
	ghdl -r $(GHDL_OPTS) $@ $(GHDL_RUN_OPTS)

%_tb: ../rtl/housekeeping/%.vhd housekeeping/%_tb.vhd
	ghdl -a $(GHDL_OPTS) $^
	ghdl -e $(GHDL_OPTS) $@
	ghdl -r $(GHDL_OPTS) $@ $(GHDL_RUN_OPTS)

%_tb: ../rtl/data_streamer/%.vhd data_streamer/%_tb.vhd
	ghdl -a $(GHDL_OPTS)  $^
	ghdl -e $(GHDL_OPTS)  $@
	ghdl -r $(GHDL_OPTS)  $@ $(GHDL_RUN_OPTS) 


%.vcd: %_tb
	ghdl -r $(GHDL_OPTS) $^ --vcd=$@
%.ghw: %_tb
	ghdl -r $(GHDL_OPTS) $^ --wave=$@


clean:
	ghdl --clean
	rm -f output/*
	rm -f *-obj93.cf *.vcd *.o *.ghw *_tb


