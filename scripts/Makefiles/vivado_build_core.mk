# This Makefile provides generic instructions for building
# (i.e. synthesizing and implementing) a design with Xilinx Vivado.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - PROJ_ROOT: path to project root directory
#        - SCRIPTS_ROOT: path to project scripts directory
#        - TOP: name of top-level module to build
#        - OUT_DIR: path to build output files

# -----------------------------------------------
# Include base Vivado build Make instructions
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_build_base.mk

# Export Make variables for use in Tcl scripts
export TOP
export OUT_DIR ?= $(COMPONENT_OUT_PATH)

VIVADO_LOG_DIR = $(OUT_DIR)

# -----------------------------------------------
# Command
# -----------------------------------------------
VIVADO_CMD = $(VIVADO_CMD_BASE) -source $(VIVADO_SCRIPTS_ROOT)/build_ooc.tcl

# -----------------------------------------------
# Targets
# -----------------------------------------------

_synth:    $(OUT_DIR)/$(TOP).synth.dcp
_opt:      $(OUT_DIR)/$(TOP).opt.dcp
_place:    $(OUT_DIR)/$(TOP).place.dcp
_phys_opt: $(OUT_DIR)/$(TOP).phys_opt.dcp
_route:    $(OUT_DIR)/$(TOP).route.dcp
.PHONY: _synth _opt _place _phys_opt _route

$(OUT_DIR):
	@mkdir $(OUT_DIR)

_clean_build: _clean_logs
	@rm -rf $(OUT_DIR)

# pre_synth hook to be described in 'parent' Makefile
# (can be used to trigger regmap or IP generation before launching synthesis)
$(OUT_DIR)/$(TOP).synth.dcp: $(OUT_DIR) pre_synth
	$(VIVADO_CMD) -tclargs synth 0

$(OUT_DIR)/$(TOP).opt.dcp: $(OUT_DIR)/$(TOP).synth.dcp
	$(VIVADO_CMD) -tclargs opt 1

$(OUT_DIR)/$(TOP).place.dcp: $(OUT_DIR)/$(TOP).opt.dcp
	$(VIVADO_CMD) -tclargs place 1

$(OUT_DIR)/$(TOP).phys_opt.dcp: $(OUT_DIR)/$(TOP).place.dcp
	$(VIVADO_CMD) -tclargs phys_opt 1

$(OUT_DIR)/$(TOP).route.dcp: $(OUT_DIR)/$(TOP).phys_opt.dcp
	$(VIVADO_CMD) -tclargs route 1


