# This Makefile provides generic instructions for building
# (i.e. synthesizing and implementing) a design with Xilinx Vivado.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - SCRIPTS_ROOT: path to project scripts directory
#        - TOP: name of top-level module to build
# -----------------------------------------------
# Configure default user sources/constraints for OOC flow
# -----------------------------------------------
SOURCES_TCL_USER ?= $(abspath sources.tcl)
CONSTRAINTS_XDC_USER ?= $(abspath timing_ooc.xdc place_ooc.xdc)

export SOURCES_TCL_USER
export CONSTRAINTS_XDC_USER

# -----------------------------------------------
# Command
# -----------------------------------------------
VIVADO_BUILD_CMD_BASE = $(VIVADO_CMD_BASE) -source $(VIVADO_SCRIPTS_ROOT)/build_ooc.tcl

VIVADO_BUILD_CMD = $(VIVADO_BUILD_CMD_BASE) -mode batch
VIVADO_BUILD_CMD_GUI = $(VIVADO_BUILD_CMD_BASE) -mode gui

# -----------------------------------------------
# Configure build flow
# -----------------------------------------------
BUILD_STAGES = synth opt place

# -----------------------------------------------
# Output files
# -----------------------------------------------
SYNTH_DCP_FILE = $(PROJ_DIR)/$(PROJ_NAME).runs/synth_1/$(TOP).dcp
OPT_TIMING_SUMMARY = $(PROJ_DIR)/$(PROJ_NAME).runs/impl_1/opt_report_timing_summary_0.rpt
BUILD_SUMMARY_JSON = $(COMPONENT_OUT_PATH)/$(TOP).opt.summary.json
BUILD_SUMMARY_XML = $(COMPONENT_OUT_PATH)/$(TOP).opt.summary.xml

# -----------------------------------------------
# Synthesis targets
# -----------------------------------------------
define BUILD_CORE_STAGE_TARGET
_build_core_$(stage): _$(stage)
	@$(MAKE) -s _build_core_synth_lib
endef
$(foreach stage,$(BUILD_STAGES),$(eval $(BUILD_CORE_STAGE_TARGET)))

_build_core_synth_lib: | $(COMPONENT_OUT_SYNTH_PATH)
	@echo "----------------------------------------------------------"
	@echo "Compiling synthesis library '$(COMPONENT_NAME)' ..."
	@echo
	@-rm -rf $(COMPONENT_OUT_SYNTH_PATH)/*.f
	@echo $(abspath $(SYNTH_DCP_FILE)) > $(COMPONENT_OUT_SYNTH_PATH)/dcp_srcs.f
	@echo "Done."

# -----------------------------------------------
# Validation targets
# -----------------------------------------------
_build_core_summary:
	@test -e $(OPT_TIMING_SUMMARY) && \
		$(VIVADO_SCRIPTS_ROOT)/gen_summary.py $(OPT_TIMING_SUMMARY) --build-name $(TOP).opt --summary-json-file $(BUILD_SUMMARY_JSON) || \
		echo "Failed to generate build summary. Timing summary ($(OPT_TIMING_SUMMARY)) not available. Design must first be synthesized and optimized."

_build_core_validate: _build_core_summary
	@$(VIVADO_SCRIPTS_ROOT)/check_timing.py $(BUILD_SUMMARY_JSON) --junit-xml-file $(BUILD_SUMMARY_XML) --wns-min $(WNS_MIN) --tns-min $(TNS_MIN)

.PHONY: _build_core_summary _build_core_validate

# -----------------------------------------------
# Info targets
# -----------------------------------------------
_vivado_build_core_info: _vivado_info
	@echo "------------------------------------------------------"
	@echo "OOC build configuration"
	@echo "------------------------------------------------------"
	@echo "TOP                 : $(TOP)"

_build_core_info: _vivado_build_core_info _compile_info

.PHONY: _vivado_build_core_info _build_core_info

# -----------------------------------------------
# Include base Vivado build Make instructions
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_build_base.mk


