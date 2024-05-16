# This Makefile provides generic functionality for source libraries,
# including make targets for compiling source components for use
# in simulations and builds.
#
# Usage: this Makefile is used by including it in a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - LIB_NAME    : name of source library (used for reporting only)
#        - COMPONENT   : target of library operation (reg/ip/info/compile/synth/opt/clean)
#        - CFG_ROOT    : path to configuration files (i.e. part.mk)
#        - OUTPUT_ROOT : path to output (generated) files
#        - LIB_ENV     : library-specific environment variables to be passed as arguments to library operations
#        - USER_ENV    : user-specific environment variables to be passed as arguments to library operations
# ----------------------------------------------------
# Assign variable defaults
# ----------------------------------------------------
LIB_NAME ?= "Unnamed library"

# ----------------------------------------------------
# Help
# ----------------------------------------------------
_help: __header _usage

_usage: __usage

__space := $(EMPTY) $(EMPTY)
__blank_line = \
	@echo ""

__header:
	@echo $(LIB_NAME)
	@echo "========================================"
ifdef LIB_DESC
	@echo $(LIB_DESC)
endif
	@echo ""

__usage:
	@echo  "Usage:"
	@echo  "  make [$(subst $(__space),|,$(strip $(LIB_OPS)))] COMPONENT=<component_ref>"
	@echo  "Examples:"
	@echo  "  make compile COMPONENT=axi.rtl"
	@echo  "  make info COMPONENT=vendorx.component.verif"


.PHONY: _help __header __usage

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
# Environment
# ----------------------------------------------------
# The config here allows for select environment variables
# to be passed explicitly to all library calls and subcalls
#
# Specify entries as:
# e.g. ENV = VAR1_NAME=VAR1_VALUE VAR2_NAME=VAR2_VALUE
#
# Common environment
COMMON_ENV = \
	CFG_ROOT=$(CFG_ROOT)

# Library-specific environment (optional)
LIB_ENV ?=

# User-specific environment (optional)
USER_ENV ?=

# ----------------------------------------------------
# Targets
# ----------------------------------------------------

# Enumerate library operations
LIB_OPS = reg ip info compile synth opt build driver clean

# Define prerequisite targets
__info:
	@echo "------------------------------------------------------"
	@echo "Source library configuration"
	@echo "------------------------------------------------------"
	@echo "LIB_NAME            : $(LIB_NAME)"
	@echo "COMMON_ENV          : $(COMMON_ENV)"
	@echo "LIB_ENV             : $(LIB_ENV)"
	@echo "USER_ENV            : $(USER_ENV)"

# By default, prerequisite targets are empty
$(foreach target,$(filter-out info,$(LIB_OPS)),$(eval __$(target):))

.PHONY: $(addprefix __,$(LIB_OPS))

# Create targets
# - targets have identical structure, and use the same Makefile recipe
# - a target is created for each of the operations listed in LIB_OPS,
#   prefixed with '_'
#   e.g. _reg, _ip, _compile, etc.

ifdef COMPONENT
ifneq ($(SUBLIBRARY),)

# If component is in sub-library, pass job to sub-library
define LIB_OP_RULE
_$(target): __$(target) | $(OUTPUT_ROOT)
	@$(MAKE) -s -C $(SUBLIB_SRC_ROOT) $(target) COMPONENT=$(SUBLIB_COMPONENT) OUTPUT_ROOT=$(OUTPUT_ROOT)/$(SUBLIBRARY) $(COMMON_ENV) $(LIB_ENV) $(USER_ENV)
endef
else

# If component is in local library, check that it exists
ifneq ($(wildcard $(COMPONENT_SRC_PATH)/Makefile),)
# If so, run compile target for component
define LIB_OP_RULE
_$(target): __$(target) | $(OUTPUT_ROOT)
	@$(MAKE) -s -C $(COMPONENT_SRC_PATH) $(target) OUTPUT_ROOT=$(OUTPUT_ROOT) $(COMMON_ENV) $(LIB_ENV) $(USER_ENV)
endef

# If not, print helpful error message
else
define LIB_OP_RULE
_$(target): __$(target) | $(OUTPUT_ROOT)
	$(error Component $(COMPONENT) could not be found)
endef
endif
endif
else
# If no component is specified, generate helpful error message
define LIB_OP_RULE
_$(target): __$(target) | $(OUTPUT_ROOT)
	@echo "ERROR: no component specified."
	@$(MAKE) -s _usage
	@false
endef
endif
$(foreach target,$(LIB_OPS),$(eval $(LIB_OP_RULE)))

.PHONY: $(addprefix _,$(LIB_OPS))

_clean_all:
	@echo -n "Removing all output products... "
	@-rm -rf $(OUTPUT_ROOT)
	@echo "Done."

.PHONY: _clean_all

_refresh_ip:
	@echo "----------------------------------------------------------"
	@echo "Forcing refresh of IP output products for $(LIB_NAME) ..."
	@find $(OUTPUT_ROOT) -type d -name .xci -prune -exec touch {}/.refresh \; 2> /dev/null || true
	@echo
	@echo "Done."

_refresh_regio:
	@echo "----------------------------------------------------------"
	@echo "Forcing refresh of regio output products for $(LIB_NAME) ..."
	@find $(OUTPUT_ROOT) -type d -name regio -prune -exec rm -rf {} \; 2> /dev/null || true
	@echo
	@echo "Done."

_refresh: _refresh_ip _refresh_regio

.PHONY: _refresh_ip _refresh_regio _refresh

$(OUTPUT_ROOT):
	@mkdir -p $@
