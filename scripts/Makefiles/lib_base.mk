# This Makefile provides generic functionality for source libraries,
# including make targets for compiling source components for use
# in simulations and builds.
#
# Usage: this Makefile is used by including it in a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - LIB_NAME : name of source library (used for reporting only)
#        - COMPONENT : 


# ----------------------------------------------------
# Assign variable defaults
# ----------------------------------------------------
LIB_NAME ?= "Unnamed library"

# ----------------------------------------------------
# Help
# ----------------------------------------------------
_help: __header __compile_help __compile_clean_help __reg_help

__header:
	@echo $(LIB_NAME)
	@echo "========================================"
ifdef LIB_DESC
	@echo $(LIB_DESC)
endif
	@echo ""

__blank_line = \
	@echo ""

.PHONY: _help __header

# ----------------------------------------------------
# Config
# ----------------------------------------------------
# Component/library reference functions
include $(SCRIPTS_ROOT)/Makefiles/component_funcs.mk

# Construct full path to component source
ifdef COMPONENT
SUBLIBRARY = $(call get_lib_from_ref,$(COMPONENT))
ifneq ($(SUBLIBRARY),)
SUBLIB_SRC_ROOT = $(call get_lib_path,$(SUBLIBRARY))
SUBLIB_COMPONENT = $(call pop_lib_from_ref,$(COMPONENT))
else
COMPONENT_SRC_PATH = $(SRC_ROOT)/$(call get_component_src_path_from_ref,$(COMPONENT))
endif
endif

# ----------------------------------------------------
# Compile for simulation
# ----------------------------------------------------
# Compile simulation library for specified component
__compile_usage = \
	@echo  "Usage:";\
	echo  "  make compile COMPONENT=<component_ref>"; \
	echo  "Examples:"; \
	echo  "  make compile COMPONENT=axi.rtl"; \
	echo  "  make compile COMPONENT=vendorx.component.verif"

__compile_clean_usage = \
    @echo  "Usage:";\
	echo  "  make compile_clean [COMPONENT=<component_ref>]"; \
	echo  "Examples:"; \
	echo  "  make compile_clean COMPONENT=axi.rtl"; \
	echo  "  make compile_clean COMPONENT=vendorx.component.verif"; \
	echo  "  make compile_clean (all components in all libraries)"

__compile_help:
	$(__blank_line)
	@echo 'Compile'
	@echo '-------'
	@echo '  - compile simulation libraries'
	$(__compile_usage)

__compile_clean_help:
	$(__blank_line)
	@echo 'Compile clean'
	@echo '-------------'
	@echo '  - clean compile objects'
	$(__compile_clean_usage)

# Generate register RTL for specified component
__reg_usage = \
	@echo  "Usage:";\
	echo  "  make reg COMPONENT=<component_ref>"; \
	echo  "Examples:"; \
	echo  "  make reg COMPONENT=axi.rtl"; \
	echo  "  make reg COMPONENT=vendorx.component.verif"

__reg_help:
	$(__blank_line)
	@echo 'Register gen'
	@echo '------------'
	@echo '  - generate register RTL'
	$(__reg_usage)

.PHONY: __reg_help

_compile: | $(OUTPUT_ROOT)
ifdef COMPONENT
ifneq ($(SUBLIBRARY),)
# If component is in sub-library, pass compile job to sub-library
	@$(MAKE) -s -C $(SUBLIB_SRC_ROOT) compile COMPONENT=$(SUBLIB_COMPONENT) CFG_ROOT=$(CFG_ROOT) OUTPUT_ROOT=$(OUTPUT_ROOT)/$(SUBLIBRARY)
else
# If component is in local library, check that it exists
ifneq ($(wildcard $(COMPONENT_SRC_PATH)/Makefile),)
# If so, run compile target for component
	@$(MAKE) -s -C $(COMPONENT_SRC_PATH) compile CFG_ROOT=$(CFG_ROOT) OUTPUT_ROOT=$(OUTPUT_ROOT)
else
# If not, print helpful error message
	$(error Component $(COMPONENT) could not be found)
endif
endif
else
# If no component is specified, generate helpful error message
	@echo "ERROR: no component specified."
	$(__compile_usage)
	@false
endif

# Clean compile products
_compile_clean:
ifdef COMPONENT
ifneq ($(SUBLIBRARY),)
# If component is in sub-library, pass clean job to sub-library
	@$(MAKE) -s -C $(SUBLIB_SRC_ROOT) compile_clean COMPONENT=$(SUBLIB_COMPONENT) CFG_ROOT=$(CFG_ROOT) OUTPUT_ROOT=$(OUTPUT_ROOT)/$(SUBLIBRARY)
else
# If component is in local library, check that it exists
ifneq ($(wildcard $(COMPONENT_SRC_PATH)/Makefile),)
# If so, run compile clean target for component
	@$(MAKE) -s -C $(COMPONENT_SRC_PATH) clean CFG_ROOT=$(CFG_ROOT) OUTPUT_ROOT=$(OUTPUT_ROOT)
else
# If not, print helpful error message
	$(error Component $(COMPONENT) could not be found)
endif
endif
else
# I no component is specified, clean all components in all libraries
	@-for lib in $(call get_libs,$(LIBRARIES)); do \
		$(MAKE) -s -C $(call get_lib_path,$$lib) compile_clean; \
	done
	@-rm -rf $(OUTPUT_ROOT)/$(SIMLIB_DIRNAME)
endif

.PHONY: _compile _compile_clean

_reg: | $(OUTPUT_ROOT)
ifdef COMPONENT
ifneq ($(SUBLIBRARY),)
# If component is in sub-library, pass compile job to sub-library
	@$(MAKE) -s -C $(SUBLIB_SRC_ROOT) reg COMPONENT=$(SUBLIB_COMPONENT) CFG_ROOT=$(CFG_ROOT) OUTPUT_ROOT=$(OUTPUT_ROOT)/$(SUBLIBRARY)
else
# If component is in local library, check that it exists
ifneq ($(wildcard $(COMPONENT_SRC_PATH)/Makefile),)
# If so, run compile target for component
	@$(MAKE) -s -C $(COMPONENT_SRC_PATH) reg CFG_ROOT=$(CFG_ROOT) OUTPUT_ROOT=$(OUTPUT_ROOT)
else
# If not, print helpful error message
	$(error Component $(COMPONENT) could not be found)
endif
endif
else
# If no component is specified, generate helpful error message
	@echo "ERROR: no component specified."
	$(__compile_usage)
	@false
endif

.PHONY: _reg

_synth:
ifdef COMPONENT
ifneq ($(SUBLIBRARY),)
# If component is in sub-library, pass compile job to sub-library
	@$(MAKE) -s -C $(SUBLIB_SRC_ROOT) synth COMPONENT=$(SUBLIB_COMPONENT) CFG_ROOT=$(CFG_ROOT) OUTPUT_ROOT=$(OUTPUT_ROOT)/$(SUBLIBRARY)
else
# If component is in local library, check that it exists
ifneq ($(wildcard $(COMPONENT_SRC_PATH)/Makefile),)
# If so, run compile target for component
	@$(MAKE) -s -C $(COMPONENT_SRC_PATH) synth CFG_ROOT=$(CFG_ROOT) OUTPUT_ROOT=$(OUTPUT_ROOT)
else
# If not, print helpful error message
	$(error Component $(COMPONENT) could not be found)
endif
endif
else
# If no component is specified, generate helpful error message
	@echo "ERROR: no component specified."
	$(__compile_usage)
	@false
endif

.PHONY: _synth

_info:
ifdef COMPONENT
ifneq ($(SUBLIBRARY),)
# If component is in sub-library, pass request to sub-library
	@$(MAKE) -s -C $(SUBLIB_SRC_ROOT) info COMPONENT=$(SUBLIB_COMPONENT) CFG_ROOT=$(CFG_ROOT) OUTPUT_ROOT=$(OUTPUT_ROOT)/$(SUBLIBRARY)
else
# If component is in local library, check that it exists
ifneq ($(wildcard $(COMPONENT_SRC_PATH)/Makefile),)
# If so, run target for component
	@$(MAKE) -s -C $(COMPONENT_SRC_PATH) info CFG_ROOT=$(CFG_ROOT) OUTPUT_ROOT=$(OUTPUT_ROOT)
else
# If not, print helpful error message
	$(error Component $(COMPONENT) could not be found)
endif
endif
else
# If no component is specified, generate helpful error message
	@echo "ERROR: no component specified."
	$(__compile_usage)
	@false
endif

.PHONY: _info

_clean:
	@echo -n "Removing all output products... "
	@-rm -rf $(OUTPUT_ROOT)
	@echo "Done."

.PHONY: _clean

$(OUTPUT_ROOT):
	@mkdir -p $@
