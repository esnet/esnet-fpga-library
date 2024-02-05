# ----------------------------------------------------
# Import environment variables
# ----------------------------------------------------
$(foreach env,$(LIB_ENV)   ,$(eval $(env)))
$(foreach env,$(USER_ENV)  ,$(eval $(env)))

# ----------------------------------------------------
# Import functions for managing/manipulating component and library references
# ----------------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/component_funcs.mk

# ----------------------------------------------------
# Configuration
# ----------------------------------------------------
# Synthesize component library and subcomponent names based on path relative to IP_ROOT
# e.g. if IP_ROOT is SRC_ROOT/src/axi4s and subcomponent path is SRC_ROOT/src/axi4s/rtl
#      the component library will be 'axi4s' and the subcomponent name will be 'rtl'
IP_NAME := $(notdir $(abspath $(IP_ROOT)))
IP_PATH := $(shell realpath --relative-to $(SRC_ROOT) $(IP_ROOT))

# Determine reference to component base, i.e. the 'parent' of the component
# e.g. for a component called vendorx.axi.rtl the component base is vendorx.axi
__COMPONENT_BASE_PATH := $(shell realpath --relative-to $(IP_ROOT)/.. ..)
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
COMPONENT_OUT_PATH := $(OUTPUT_ROOT)/$(COMPONENT_PATH)
