# name:    Makefile
# author:  Theodor Fragner
# date:    10.10.2019
# content: Makefile for compiling vhdl entities using ghdl

# program to compile and run vhdl simulation
VHDL_CMD = ghdl

# include the standard libraries
VHDL_ARG = --ieee=synopsys

# name of top-level vhdl design entity
TOP_UNIT = TB_DE10_LITE
TOP_OBJ  = $(TOP_UNIT).o

# object files in hierarchical order
ALL_UNIT = DE10_LITE_const_pkg DE10_LITE TB_DE10_LITE
ALL_OBJ  = $(patsubst %, %.o, $(ALL_UNIT))

# program to display waveforms
DISPLAY_CMD = gtkwave

# waveform is stored here
DISPLAY_FILE = wave.ghw

# display generated waveform graphically
.PHONY: sim
sim: $(DISPLAY_FILE)
	$(DISPLAY_CMD) $(DISPLAY_FILE)

# remove all compiled files
.PHONY: clean
clean:
	-rm $(ALL_OBJ)
	-rm e~*.o

# create top-level executable
$(TOP_UNIT): $(ALL_OBJ)
	$(VHDL_CMD) -e $(VHDL_ARG) $(TOP_UNIT)

# create waveform by running simulation
$(DISPLAY_FILE): $(TOP_UNIT)
	$(VHDL_CMD) -r $(TOP_UNIT) --stop-time=10ms --disp-time --wave=$(DISPLAY_FILE)

# compile single vhdl files
%.o: %.vhd
	$(VHDL_CMD) -a $(VHDL_ARG) $(patsubst %.o, %.vhd, $@)
