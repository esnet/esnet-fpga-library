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
VIVADO_CMD = $(VIVADO_CMD_BASE_NO_LOG) -source $(VIVADO_SCRIPTS_ROOT)/build.tcl

# -----------------------------------------------
# Targets
# -----------------------------------------------
_synth:     $(BUILD_OUTPUT_DIR)/$(TOP).synth.dcp
_opt:       $(BUILD_OUTPUT_DIR)/$(TOP).opt.dcp
_place:     $(BUILD_OUTPUT_DIR)/$(TOP).place.dcp
_place_opt: $(BUILD_OUTPUT_DIR)/$(TOP).place_opt.dcp
_route:     $(BUILD_OUTPUT_DIR)/$(TOP).route.dcp
_route_opt: $(BUILD_OUTPUT_DIR)/$(TOP).route_opt.dcp
_bitstream: $(BUILD_OUTPUT_DIR)/$(TOP).bit
_mcs:       $(BUILD_OUTPUT_DIR)/$(TOP).mcs
_validate:  $(VUILD_OUTPUT_DIR)/$(TOP).route_opt.summary.xml

.PHONY: _synth _opt _place _place_opt _route _route_opt _bitstream _mcs _validate

# pre_synth hook to be described in 'parent' Makefile
# (can be used to trigger regmap or IP generation before launching synthesis)
$(BUILD_OUTPUT_DIR)/$(TOP).synth.dcp: $(BUILD_OUTPUT_DIR) pre_synth
	$(VIVADO_CMD) -log $(BUILD_OUTPUT_DIR)/$(TOP).synth.log -tclargs synth 0

$(BUILD_OUTPUT_DIR)/$(TOP).opt.dcp: $(BUILD_OUTPUT_DIR)/$(TOP).synth.dcp
	$(VIVADO_CMD) -log $(BUILD_OUTPUT_DIR)/$(TOP).opt.log -tclargs opt 1

$(BUILD_OUTPUT_DIR)/$(TOP).place.dcp: $(BUILD_OUTPUT_DIR)/$(TOP).opt.dcp
	$(VIVADO_CMD) -log $(BUILD_OUTPUT_DIR)/$(TOP).place.log -tclargs place 1

$(BUILD_OUTPUT_DIR)/$(TOP).place_opt.dcp: $(BUILD_OUTPUT_DIR)/$(TOP).place.dcp
	$(VIVADO_CMD) -log $(BUILD_OUTPUT_DIR)/$(TOP).place_opt.log -tclargs place_opt 1

$(BUILD_OUTPUT_DIR)/$(TOP).route.dcp: $(BUILD_OUTPUT_DIR)/$(TOP).place_opt.dcp
	$(VIVADO_CMD) -log $(BUILD_OUTPUT_DIR)/$(TOP).route.log -tclargs route 1

$(BUILD_OUTPUT_DIR)/$(TOP).route_opt.dcp: $(BUILD_OUTPUT_DIR)/$(TOP).route.dcp
	$(VIVADO_CMD) -log $(BUILD_OUTPUT_DIR)/$(TOP).route_opt.log -tclargs route_opt 1

$(BUILD_OUTPUT_DIR)/$(TOP).bit: $(BUILD_OUTPUT_DIR)/$(TOP).route_opt.dcp
	$(VIVADO_CMD) -log $(BUILD_OUTPUT_DIR)/$(TOP).bit.log -tclargs bitstream 1

$(BUILD_OUTPUT_DIR)/$(TOP).mcs: $(BUILD_OUTPUT_DIR)/$(TOP).bit
	$(VIVADO_CMD) -log $(BUILD_OUTPUT_DIR)/$(TOP).mcs.log -tclargs mcs 0


