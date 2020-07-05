.PHONY: clean all
.PRECIOUS: output/work-obj93.cf output/work-obj08.cf


print-% : ; $(info $* is a $(flavor $*) variable set to [$($*)]) @true


testfiles := $(wildcard housekeeping/*.vhd) $(wildcard data_streamer/*.vhd)
runfiles := $(patsubst %_tb, %.ghw, $(basename $(notdir $(testfiles))))

all: $(basename $(notdir $(testfiles)))
# $(warning $(basename $(notdir $(testfiles))))

runall: $(runfiles)

#GHDL_OPTS = --ieee=synopsys -fexplicit -Plattice/ecp5u/v93
GHDL_OPTS = --workdir=output --std=08 -fsynopsys
#GHDL_RUN_OPTS = --assert-level=warning --ieee-asserts=disable
#GHDL_RUN_OPTS = --psl-report=$^.test_coverage.rpt

# Rules for analysys:
# analysis results in object  files in the work dir
# for this to work it is paramount that no modules share the same name
output/%.o: ../rtl/%.vhd
	ghdl -a $(GHDL_OPTS) $(firstword $^)
output/%.o: ../rtl/housekeeping/%.vhd
	ghdl -a $(GHDL_OPTS) $(firstword $^)
output/%.o: ../rtl/housekeeping/calibration/%.vhd
	ghdl -a $(GHDL_OPTS) $(firstword $^)
output/%.o: ../rtl/housekeeping/calibration/versatile_fft/trunk/single_unit/src/%.vhd
	ghdl -a $(GHDL_OPTS) $(firstword $^)
output/%.o: ../rtl/data_streamer/%.vhd
	ghdl -a $(GHDL_OPTS) $(firstword $^)
output/%.o: data_streamer/%.vhd
	ghdl -a $(GHDL_OPTS) $(firstword $^)
output/%.o: housekeeping/%.vhd
	ghdl -a $(GHDL_OPTS) $(firstword $^)


output/lfsr.o: ../rtl/data_streamer/test_source.vhd
	ghdl -a $(GHDL_OPTS) $(firstword $^)

# dp_ram needs an extra flag
output/dp_ram_scl.o: ../rtl/housekeeping/calibration/versatile_fft/trunk/single_unit/src/dp_ram_scl.vhd
	ghdl -a $(GHDL_OPTS) -frelaxed $(firstword $^)

calibration_tb: output/calibration_tb.o
	ghdl -e $(GHDL_OPTS) -frelaxed $@


# Rules for elaboration:
%: output/%.o
	ghdl -e $(GHDL_OPTS) $@

# Rules for running:
%.ghw: %_tb
	ghdl -r $(GHDL_OPTS) $^ --wave=$@ $(GHDL_RUN_OPTS)




# rules for generating depfiles
sourcefiles := $(wildcard housekeeping/*.vhd) $(wildcard data_streamer/*.vhd) $(wildcard ../rtl/housekeeping/*.vhd) $(wildcard ../rtl/housekeeping/calibration/*.vhd)  $(wildcard ../rtl/housekeeping/calibration/versatile_fft/trunk/single_unit/src/*.vhd) $(wildcard ../rtl/data_streamer/*.vhd)
depfiles := $(addprefix .depinfo/,$(addsuffix .d,$(basename $(notdir $(sourcefiles)))))

.depinfo/%.d: ../rtl/housekeeping/%.vhd
	@python3 makedepends.py $^ $@
.depinfo/%.d: ../rtl/housekeeping/calibration/%.vhd
	@python3 makedepends.py $^ $@
.depinfo/%.d: ../rtl/housekeeping/calibration/versatile_fft/trunk/single_unit/src/%.vhd
	@python3 makedepends.py $^ $@
.depinfo/%.d: ../rtl/data_streamer/%.vhd
	@python3 makedepends.py $^ $@
.depinfo/%.d: data_streamer/%.vhd
	@python3 makedepends.py $^ $@
.depinfo/%.d: housekeeping/%.vhd
	@python3 makedepends.py $^ $@


$(depfiles):

-include $(depfiles)

clean:
	ghdl --clean
	rm -f output/*
	rm -f .depinfo/*
	rm -f *-obj93.cf *.vcd *.o *.ghw *_tb



