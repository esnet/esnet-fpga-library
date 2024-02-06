# ----------------------------------------------------
# Generate component details
#
# Provides the following:
#   - COMPONENT_REF: reference spec for component to be compiled
#   - COMPONENT_NAME: standardized component name for component to be compiled
#   - COMPONENT_PATH: path to component source
#   - COMPONENT_BASE: component reference, not including suffix (subcomponent)
#   - SUBCOMPONENT: subcomponent reference, equivalent to suffix of component reference
# ----------------------------------------------------
# Import environment variables
# ----------------------------------------------------
$(foreach env,$(LIB_ENV)   ,$(eval $(env)))
$(foreach env,$(USER_ENV)  ,$(eval $(env)))

# -----------------------------------------------
# Import part configuration
# -----------------------------------------------
include $(CFG_ROOT)/part.mk

# ----------------------------------------------------
# Default variables
# ----------------------------------------------------
# Subdirectory for IP outputs
# (by default, all IP is maintained in a separate project per part)
IP_OUT_SUBDIR ?= $(PART)

# ----------------------------------------------------
# Import functions for managing/manipulating component and library references
# ----------------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/component_funcs.mk

# ----------------------------------------------------
# Configuration
# ----------------------------------------------------
# Synthesize component library and subcomponent names based on path relative to COMPONENT_ROOT
# e.g. if COMPONENT_ROOT is SRC_ROOT/src/axi4s and subcomponent path is SRC_ROOT/src/axi4s/rtl
#      the component name will be 'axi4s' and the subcomponent name will be 'rtl'
COMPONENT_ROOT_NAME := $(notdir $(abspath $(COMPONENT_ROOT)))
COMPONENT_ROOT_PATH := $(shell realpath --relative-to $(SRC_ROOT) $(COMPONENT_ROOT))

# Determine reference to component base, i.e. the 'parent' of the component
# e.g. for a component called vendorx.axi.rtl the component base is vendorx.axi
__COMPONENT_BASE_PATH := $(shell realpath --relative-to $(COMPONENT_ROOT)/.. ..)
COMPONENT_BASE := $(call get_component_ref_from_path,$(__COMPONENT_BASE_PATH))

# Determine subcomponent
# e.g. for a component called vendorx.axi.rtl the subcomponent is rtl
SUBCOMPONENT:= $(call __to_lower,$(notdir $(abspath $(shell pwd))))

# Synthesize standard reference for component
COMPONENT_REF := $(if $(COMPONENT_BASE),$(COMPONENT_BASE).,)$(SUBCOMPONENT)

# Synthesize name/path from reference
COMPONENT_PATH := $(call get_component_path_from_ref,$(COMPONENT_REF))
COMPONENT_NAME := $(call get_component_name_from_ref,$(COMPONENT_REF))

# Synthesize output paths
COMPONENT_OUT_PATH := $(abspath $(call get_component_out_path_from_ref,$(COMPONENT_REF),$(OUTPUT_ROOT),$(IP_OUT_SUBDIR)))

COMPONENT_OUT_SYNTH_PATH := $(COMPONENT_OUT_PATH)/synth

# ----------------------------------------------------
# Info target
# ----------------------------------------------------
.component_info:
	@echo "------------------------------------------------------"
	@echo "Component configuration"
	@echo "------------------------------------------------------"
	@echo "COMPONENT_ROOT_NAME : $(COMPONENT_ROOT_NAME)"
	@echo "COMPONENT_NAME      : $(COMPONENT_NAME)"
	@echo "SUBCOMPONENT        : $(SUBCOMPONENT)"
	@echo "COMPONENT_PATH      : $(COMPONENT_PATH)"
	@echo "COMPONENT_OUT_PATH  : $(COMPONENT_OUT_PATH)"
	@echo "COMPONENT_OUT_SYNTH_PATH : $(COMPONENT_OUT_SYNTH_PATH)"
.PHONY: .component_info

