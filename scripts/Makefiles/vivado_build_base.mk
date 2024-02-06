# This Makefile provides generic instructions for building
# (i.e. synthesizing and implementing) a design with Xilinx Vivado.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - SCRIPTS_ROOT: path to project scripts directory
#        - CFG_ROOT: path to the part configuration file(s)
#        - BUILD_OUTPUT_DIR: path to build output products
#        - TOP: top-level module for build

# -----------------------------------------------
# Import base Vivado definitions/targets
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_base.mk

# -----------------------------------------------
# Export Make variables for use in Tcl scripts
# -----------------------------------------------
export TOP
export BUILD_OUTPUT_DIR=$(COMPONENT_OUT_PATH)

# -----------------------------------------------
# Options
# -----------------------------------------------
VIVADO_LOG_DIR = $(BUILD_OUTPUT_DIR)

# Build validation paramaters
WNS_MIN ?= 0
TNS_MIN ?= 0

# -----------------------------------------------
# Targets
# -----------------------------------------------
# Create build summary in JSON format
%.summary.json: %.timing.summary.rpt
	$(VIVADO_SCRIPTS_ROOT)/gen_summary.py $< --build-name $(notdir $*) --summary-json-file $@

# (Retain summary even when it is generated as an intermediate file)
.PRECIOUS: %.summary.json

# Validate build based on JSON summary created from specific build phase
%.summary.xml: %.summary.json
	$(VIVADO_SCRIPTS_ROOT)/check_timing.py $< --junit-xml-file $@ --wns-min $(WNS_MIN) --tns-min $(TNS_MIN)

# Create build directory
$(BUILD_OUTPUT_DIR):
	@mkdir -p $(BUILD_OUTPUT_DIR)

# Remove build output directory
_clean_build: _vivado_clean_logs
	@rm -rf $(BUILD_OUTPUT_DIR)

.PHONY: _clean_build
