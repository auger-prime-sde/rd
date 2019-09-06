.PHONY: clean

#GHDL_OPTS = --ieee=synopsys -fexplicit -Plattice/ecp5u/v93
GHDL_OPTS = --workdir=output
GHDL_RUN_OPTS = --assert-level=warning --ieee-asserts=disable

all: data_streamer housekeeping

data_streamer: data_buffer_tb simple_counter_tb write_controller_tb readout_controller_tb data_writer_tb
housekeeping: spi_demux_tb spi_decoder_tb digitaloutput_tb bootsequence_tb i2c2_tb read_sequence_tb ads1015_tb
ads1015: spi_decoder_tb read_sequence_tb i2c2_tb


# the common housekeeping definitions are used in a few places
hk_common: ../rtl/housekeeping/common.vhd
	ghdl -a $(GHDL_OPTS) $^
read_sequence_tb : | hk_common
i2c2_tb : | hk_common
ads1015_tb : | hk_common


# define some order constraints
write_controller_tb : | simple_counter_tb data_buffer_tb
i2c_inttest : | i2c2_tb read_sequence_tb

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

%_inttest: housekeeping/%_inttest.vhd
	ghdl -a $(GHDL_OPTS) $^
	ghdl -e $(GHDL_OPTS) $@
	ghdl -r $(GHDL_OPTS) $@ $(GHDL_RUN_OPTS)


%.vcd: %_tb
	ghdl -r $(GHDL_OPTS) $^ --vcd=$@
%.ghw: %_tb
	ghdl -r $(GHDL_OPTS) $^ --wave=$@

%.ghw: %_inttest
	ghdl -r $(GHDL_OPTS) $^ --wave=$@


clean:
	ghdl --clean
	rm -f output/*
	rm -f *-obj93.cf *.vcd *.o *.ghw *_tb


