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
# Vivado project properties
# -----------------------------------------------
PROJ_DIR = $(COMPONENT_OUT_PATH)/proj
PROJ_NAME = proj
PROJ_XPR = $(PROJ_DIR)/$(PROJ_NAME).xpr

# -----------------------------------------------
# Options
# -----------------------------------------------
# Build validation paramaters
WNS_MIN ?= 0
TNS_MIN ?= 0

# -----------------------------------------------
# Project targets
# -----------------------------------------------
_proj : | $(PROJ_XPR)
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_BUILD_CMD_GUI) -tclargs gui $(TOP) $(BUILD_OPTIONS) &

_proj_clean:
	@rm -rf $(PROJ_DIR)

.PHONY: _proj_create _proj _proj_clean

$(PROJ_XPR): | $(COMPONENT_OUT_PATH)
	@echo "----------------------------------------------------------"
	@echo "Creating OOC build project ($(COMPONENT_NAME)) ..."
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_BUILD_CMD) -tclargs create_proj $(TOP) $(BUILD_OPTIONS)
	@echo
	@echo "Done."

$(COMPONENT_OUT_PATH):
	@mkdir -p $@

# -----------------------------------------------
# Build targets
#
#   Automatically generate build stage targets
#   for all supported design stages, where
#   supported design stages are described in
#   BUILD_STAGES
# -----------------------------------------------
_pre_synth: _compile_synth

define BUILD_STAGE_RULE
_$(stage): pre_synth | $(PROJ_XPR)
	@echo "----------------------------------------------------------"
	@echo "Running $(stage)_design for '$(TOP)' OOC ..."
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_BUILD_CMD) -tclargs $(stage) $(TOP) $(BUILD_OPTIONS)
	@echo
	@echo "Done."
endef
$(foreach stage,$(BUILD_STAGES),$(eval $(BUILD_STAGE_RULE)))

.PHONY: $(foreach stage, $(BUILD_STAGES),_$(stage))

# Remove build output directory
_build_clean: _vivado_clean_logs
	@rm -rf $(COMPONENT_OUT_PATH)

.PHONY: _build_clean

# -----------------------------------------------
# Include base Vivado build Make instructions
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_compile.mk

