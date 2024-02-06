# This Makefile provides generic instructions for building
# (i.e. synthesizing and implementing) a design with Xilinx Vivado.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - SCRIPTS_ROOT: path to project scripts directory
#        - TOP: name of top-level module to build
#        - BUILD_OUTPUT_DIR: path to build output files

# -----------------------------------------------
# Include base Vivado build Make instructions
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_build_base.mk

# -----------------------------------------------
# Command
# -----------------------------------------------
VIVADO_CMD = $(VIVADO_CMD_BASE_NO_LOG) -source $(VIVADO_SCRIPTS_ROOT)/build_ooc.tcl

# -----------------------------------------------
# Targets
# -----------------------------------------------
_pre_synth: _compile_synth
_synth:     $(BUILD_OUTPUT_DIR)/$(TOP).synth.dcp
_opt:       $(BUILD_OUTPUT_DIR)/$(TOP).opt.dcp
_place:     $(BUILD_OUTPUT_DIR)/$(TOP).place.dcp
_validate:  $(BUILD_OUTPUT_DIR)/$(TOP).opt.summary.xml

.PHONY: _pre_synth _synth _opt _place _validate

# pre_synth hook to be described in 'parent' Makefile
# (can be used to trigger regmap or IP generation before launching synthesis)
$(BUILD_OUTPUT_DIR)/$(TOP).synth.dcp: pre_synth | $(BUILD_OUTPUT_DIR)
	@echo "----------------------------------------------------------"
	@echo "Synthesizing '$(TOP)' OOC ..."
	@echo
	$(VIVADO_CMD) -log $(BUILD_OUTPUT_DIR)/$(TOP).synth.log -tclargs synth 0
	@echo
	@echo "Done."

$(BUILD_OUTPUT_DIR)/$(TOP).opt.dcp: $(BUILD_OUTPUT_DIR)/$(TOP).synth.dcp
	@echo "----------------------------------------------------------"
	@echo "Optimizing '$(TOP)' OOC ..."
	@echo
	$(VIVADO_CMD) -log $(BUILD_OUTPUT_DIR)/$(TOP).opt.log -tclargs opt 1
	@echo
	@echo "Done."

$(BUILD_OUTPUT_DIR)/$(TOP).place.dcp: $(BUILD_OUTPUT_DIR)/$(TOP).opt.dcp
	@echo "----------------------------------------------------------"
	@echo "Placing '$(TOP)' OOC ..."
	@echo
	$(VIVADO_CMD) -log $(BUILD_OUTPUT_DIR)/$(TOP).place.log -tclargs place 1
	@echo
	@echo "Done."

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
include $(SCRIPTS_ROOT)/Makefiles/vivado_compile.mk

