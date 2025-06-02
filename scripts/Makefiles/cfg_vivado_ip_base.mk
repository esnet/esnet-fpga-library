# This Makefile provides generic definitions for using/manipulating
# vivado IP definitions
#
# Usage: this Makefile is used by including it from a 'parent' Makefile,
#        where the parent can call the targets defined here
# -----------------------------------------------
# Include standard function helper library
include $(SCRIPTS_ROOT)/Makefiles/funcs.mk

# ------------------------------------------------------------------
# Include Vivado tool configuration
# ------------------------------------------------------------------
include $(CFG_ROOT)/vivado.mk

# ------------------------------------------------------------------
# Load version-specfic IP config where available
# ------------------------------------------------------------------
ACTIVE_VIVADO_IP_CFG_FILE = $(CFG_ROOT)/$(VIVADO_ACTIVE_VERSION)/vivado_ip.mk
PROJ_VIVADO_IP_CFG_FILE   = $(CFG_ROOT)/$(PROJ_VIVADO_VERSION)/vivado_ip.mk

ifneq ($(wildcard $(ACTIVE_VIVADO_IP_CFG_FILE)),)
# First look for config file matching 'active' Vivado version
include $(ACTIVE_VIVADO_IP_CFG_FILE)
else
ifneq ($(wildcard $(PROJ_VIVADO_IP_CFG_FILE)),)
# Otherwise load the config file corresponding to the project-secified Vivado version
include $(PROJ_VIVADO_IP_CFG_FILE)
else
# No version-specific config file is provided; proceed with defaults
endif
endif

# Get fully-qualified IP definition from IP entry
get_ipdef_from_ip = $(firstword $(subst =, ,$(1)))

# Get IP core revision from IP entry
get_ip_core_rev_from_ip = $(lastword $(subst =, , $(1)))

# Synthesize list of IP + core versions, as convenience for downstream scripts (core version format is in x_y_z format)
get_ip_ver_list = $(foreach ip,$(1),IP_VER_$(call __to_upper, $(word 3,$(subst :, ,$(ip))))=$(subst =,_,$(subst .,_,$(lastword $(subst :, ,$(ip))))))

__IP_VER_LIST = $(call get_ip_ver_list,$(VIVADO_IP))

# Synthesize env variables for each IP evaluating to core version
$(foreach ip_ver,$(__IP_VER_LIST),$(eval $(ip_ver)))

# -----------------------------------------------
# Targets
# -----------------------------------------------
# Execute Vivado to check on license status for specified IP
.vivado_ip_check:
	@vivado -mode batch -nolog -nojournal -notrace -source $(SCRIPTS_ROOT)/vivado/check_ip_license.tcl -tclargs $(VIVADO_IP) || echo "ERROR: Xilinx IP license check failed"

.PHONY: .vivado_ip_check

# Display IP version information
.vivado_ip_info:
	@echo "------------------------------------------------------"
	@echo "(Vivado) IP version info"
	@echo "------------------------------------------------------"
	@echo "VIVADO_IP :"
	@for ip in $(VIVADO_IP); do \
		echo "\t$$ip"; \
	done

.PHONY: .vivado_ip_info
