.PHONY: clean all


print-% : ; $(info $* is a $(flavor $*) variable set to [$($*)]) @true


testfiles := $(wildcard housekeeping/*.vhd) $(wildcard data_streamer/*.vhd)
all: $(basename $(notdir $(testfiles)))


#GHDL_OPTS = --ieee=synopsys -fexplicit -Plattice/ecp5u/v93
GHDL_OPTS = --workdir=output
#GHDL_RUN_OPTS = --assert-level=warning --ieee-asserts=disable

# Rules for analysys:
# analysis results in object  files in the work dir
# for this to work it is paramount that no modules share the same name
output/%.o: ../rtl/housekeeping/%.vhd
	ghdl -a $(GHDL_OPTS) $(firstword $^)
output/%.o: ../rtl/data_streamer/%.vhd
	ghdl -a $(GHDL_OPTS) $(firstword $^)
output/%.o: data_streamer/%.vhd
	ghdl -a $(GHDL_OPTS) $(firstword $^)
output/%.o: housekeeping/%.vhd
	ghdl -a $(GHDL_OPTS) $(firstword $^)

# Rules for elaboration:
%: output/%.o
	ghdl -e $(GHDL_OPTS) $@

# Rules for running:
%.ghw: %_tb
	ghdl -r $(GHDL_OPTS) $^ --wave=$@

# rules for generating depfiles
sourcefiles := $(wildcard housekeeping/*.vhd) $(wildcard data_streamer/*.vhd) $(wildcard ../rtl/housekeeping/*.vhd) $(wildcard ../rtl/data_streamer/*.vhd)
depfiles := $(addprefix .depinfo/,$(addsuffix .d,$(basename $(notdir $(sourcefiles)))))

.depinfo/%.d: ../rtl/housekeeping/%.vhd
	./makedepends.py $^ $@
.depinfo/%.d: ../rtl/data_streamer/%.vhd
	./makedepends.py $^ $@
.depinfo/%.d: data_streamer/%.vhd
	./makedepends.py $^ $@
.depinfo/%.d: housekeeping/%.vhd
	./makedepends.py $^ $@

include $(depfiles) 

clean:
	ghdl --clean
	rm -f output/*
	rm -f .depinfo/*
	rm -f *-obj93.cf *.vcd *.o *.ghw *_tb



