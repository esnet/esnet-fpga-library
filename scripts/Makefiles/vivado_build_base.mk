# This Makefile provides generic instructions for building
# (i.e. synthesizing and implementing) a design with Xilinx Vivado.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - SCRIPTS_ROOT: path to project scripts directory
#        - CFG_ROOT: path to the part configuration file(s)
# -----------------------------------------------
# Paths
# -----------------------------------------------
VIVADO_SCRIPTS_ROOT := $(SCRIPTS_ROOT)/vivado

# -----------------------------------------------
# Import default component configuration
#
# Provides the following:
#   - COMPONENT_OUT_PATH: Default output directory for component
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/component_base.mk

# -----------------------------------------------
# Export Make variables for use in Tcl scripts
# -----------------------------------------------
export TOP
export BUILD_OUTPUT_DIR ?= $(COMPONENT_OUT_PATH)

# -----------------------------------------------
# Import part configuration
# -----------------------------------------------
include $(CFG_ROOT)/part.mk

# Export part variables for use in Tcl scripts
export BOARD_REPO
export PART
export BOARD_PART

# -----------------------------------------------
# Options
# -----------------------------------------------
VIVADO_DEFAULT_OPTIONS = -mode batch -notrace -nojournal

VIVADO_OPTIONS += $(VIVADO_DEFAULT_OPTIONS)

VIVADO_LOG_NAME ?= vivado.log

# Build validation paramaters
WNS_MIN ?= 0
TNS_MIN ?= 0

# -----------------------------------------------
# Commands
# -----------------------------------------------
VIVADO_CMD_BASE_NO_LOG = vivado $(VIVADO_OPTIONS) -source $(VIVADO_SCRIPTS_ROOT)/part.tcl -source $(VIVADO_SCRIPTS_ROOT)/procs.tcl
VIVADO_CMD_BASE = $(VIVADO_CMD_BASE_NO_LOG) -log $(BUILD_OUTPUT_DIR)/$(VIVADO_LOG_NAME)

# -----------------------------------------------
# Targets
# -----------------------------------------------
#  Display part configuration
_part_cfg:
	@echo "------------------------------------------------------"
	@echo "Part configuration"
	@echo "------------------------------------------------------"
	@echo "PART:       $(PART)"
	@echo "BOARD_PART: $(BOARD_PART)"
	@echo "BOARD_REPO: $(BOARD_REPO)"

.PHONY: _part_cfg

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

# Remove any Vivado logs created in source directory
_clean_logs:
	@rm -f vivado*.jou
	@rm -f vivado*.log
	@rm -f vivado*.str
	@rm -f *.pb
	@rm -rf .Xil

# Remove build output directory
_clean_build: _clean_logs
ifneq (,$(findstring $(abspath $(PROJ_ROOT)),$(abspath $(BUILD_OUTPUT_DIR))))
	@rm -rf $(BUILD_OUTPUT_DIR)
else
	@echo 'Did not delete build directory "$(BUILD_OUTPUT_DIR)" since it does not exist within the project hierarchy.'
endif

.PHONY: _clean_logs _clean_build
