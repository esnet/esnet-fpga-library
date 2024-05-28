# This Makefile provides generic instructions for building
# (i.e. synthesizing and implementing) a design with Xilinx Vivado.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - SCRIPTS_ROOT: path to project scripts directory
#        - TOP: name of top-level module to build
# -----------------------------------------------
# Configure default user sources/constraints for top-level flow
# -----------------------------------------------
SOURCES_TCL_USER ?= $(abspath sources.tcl)
CONSTRAINTS_XDC_USER ?= $(abspath timing.xdc pins.xdc general.xdc)
# -----------------------------------------------
# Command
# -----------------------------------------------
VIVADO_BUILD_CMD_BASE = $(VIVADO_CMD_BASE) -source $(VIVADO_SCRIPTS_ROOT)/build.tcl

VIVADO_BUILD_CMD = $(VIVADO_BUILD_CMD_BASE) -mode batch
VIVADO_BUILD_CMD_GUI = $(VIVADO_BUILD_CMD_BASE) -mode gui

# -----------------------------------------------
# Configure build flow
# -----------------------------------------------
BUILD_STAGES = synth opt place place_opt route route_opt bitstream flash

# -----------------------------------------------
# Configure build options
# -----------------------------------------------
BUILD_JOBS ?= 4

BUILD_TIMESTAMP ?= $(shell date +"%s")
BITSTREAM_USERID = $(shell printf "0x%08x" $(BUILD_ID))
BITSTREAM_USR_ACCESS ?= $(BITSTREAM_USERID)

# Format as optional arguments
BUILD_OPTIONS = \
    $(VIVADO_PART_CONFIG) \
    $(VIVADO_PROJ_CONFIG) \
    -jobs $(BUILD_JOBS) \
    -sources_tcl_auto $(SOURCES_TCL_AUTO) \
    -constraints_tcl_auto $(CONSTRAINTS_TCL_AUTO) \
    $(foreach sources_tcl,$(SOURCES_TCL_USER),-sources_tcl $(sources_tcl)) \
    $(foreach constraints_xdc,$(CONSTRAINTS_XDC_USER),-constraints_xdc $(constraints_xdc)) \
    $(foreach define,$(DEFINES),-define $(define)) \
    -timestamp $(BUILD_TIMESTAMP) \
    -userid $(BITSTREAM_USERID) \
    -usr_access $(BITSTREAM_USR_ACCESS)

# -----------------------------------------------
# Output files
# -----------------------------------------------
TIMING_SUMMARY = $(PROJ_DIR)/$(PROJ_NAME).runs/impl_1/route_opt_report_timing_summary_0.rpt
BUILD_SUMMARY_JSON = $(COMPONENT_OUT_PATH)/$(TOP).opt.summary.json
BUILD_SUMMARY_XML = $(COMPONENT_OUT_PATH)/$(TOP).opt.summary.xml

# -----------------------------------------------
# Synthesis targets
# -----------------------------------------------
define BUILD_STAGE_TARGET
_build_$(stage): _$(stage)
endef
$(foreach stage,$(BUILD_STAGES),$(eval $(BUILD_STAGE_TARGET)))

# -----------------------------------------------
# Validation targets
# -----------------------------------------------
_build_summary:
	@test -e $(TIMING_SUMMARY) && \
		$(VIVADO_SCRIPTS_ROOT)/gen_summary.py $(ROUTE_TIMING_SUMMARY) --build-name $(TOP).route_opt --summary-json-file $(BUILD_SUMMARY_JSON) || \
		echo "Failed to generate build summary. Timing summary ($(TIMING_SUMMARY)) not available. Design must first be synthesized and optimized."

_build_validate: _build_summary
	@$(VIVADO_SCRIPTS_ROOT)/check_timing.py $(BUILD_SUMMARY_JSON) --junit-xml-file $(BUILD_SUMMARY_XML) --wns-min $(WNS_MIN) --tns-min $(TNS_MIN)

.PHONY: _build_core_summary _build_core_validate

# -----------------------------------------------
# Info targets
# -----------------------------------------------
_vivado_build_info: _vivado_info
	@echo "------------------------------------------------------"
	@echo "Build configuration"
	@echo "------------------------------------------------------"
	@echo "BUILD_TIMESTAMP     : $(BUILD_TIMESTAMP)"
	@echo "BUILD_ID            : $(BUILD_ID)"
	@echo "TOP                 : $(TOP)"

_build_info: _vivado_build_info _compile_info

.PHONY: _vivado_build_info _build_info

# -----------------------------------------------
# Include base Vivado build Make instructions
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_build_base.mk

