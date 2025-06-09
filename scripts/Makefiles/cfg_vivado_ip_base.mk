ifndef __CFG_VIVADO_IP_BASE_MK__
__CFG_VIVADO_IP_BASE_MK__ := defined
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
get_config_file_for_version = $(CFG_ROOT)/$(1)/vivado_ip.mk

ifneq ($(wildcard $(call get_config_file_for_version,$(VIVADO_ACTIVE_VERSION))),)
# First look for IP config file matching 'active' Vivado version, including patch (e.g. 2024.2.1_AR1)
IP_CONFIG_VERSION := $(VIVADO_ACTIVE_VERSION)
include $(call get_config_file_for_version,$(VIVADO_ACTIVE_VERSION))
else
ifneq ($(wildcard $(call get_config_file_for_version,$(VIVADO_ACTIVE_VERSION__MAJOR_MINOR))),)
# Then look for IP config file matching 'active' MAJOR/MINOR Vivado version, no patch (e.g. 2024.2.1)
IP_CONFIG_VERSION := $(VIVADO_ACTIVE_VERSION__MAJOR_MINOR)
include $(call get_config_file_for_version,$(VIVADO_ACTIVE_VERSION__MAJOR_MINOR))
else
ifneq ($(wildcard $(call get_config_file_for_version,$(VIVADO_ACTIVE_VERSION__MAJOR))),)
# Then look for IP config file matching 'active' MAJOR Vivado version, no patch (e.g. 2024.2)
IP_CONFIG_VERSION := $(VIVADO_ACTIVE_VERSION__MAJOR)
include $(call get_config_file_for_version,$(VIVADO_ACTIVE_VERSION__MAJOR))
else
ifneq ($(wildcard $(call get_config_file_for_version,$(PROJ_VIVADO_VERSION))),)
# Then look for IP config file matching 'project' Vivado version, including patch (e.g. 2025.1.1_AR1)
IP_CONFIG_VERSION := $(PROJ_VIVADO_VERSION)
include $(call get_config_file_for_version,$(PROJ_VIVADO_VERSION))
else
ifneq ($(wildcard $(call get_config_file_for_version,$(PROJ_VIVADO_VERSION__MAJOR_MINOR))),)
# Then look for IP config file matching 'project' MAJOR/MINOR Vivado version, no patch (e.g. 2025.1.1)
IP_CONFIG_VERSION := $(PROJ_VIVADO_VERSION__MAJOR_MINOR)
include $(call get_config_file_for_version,$(PROJ_VIVADO_VERSION__MAJOR_MINOR))
else
ifneq ($(wildcard $(call get_config_file_for_version,$(PROJ_VIVADO_VERSION__MAJOR))),)
# Then look for IP config file matching 'project' MAJOR Vivado version, no patch (e.g. 2025.1)
IP_CONFIG_VERSION := $(PROJ_VIVADO_VERSION__MAJOR)
include $(call get_config_file_for_version,$(PROJ_VIVADO_VERSION__MAJOR))
else
# No version-specific IP config file is provided; proceed with defaults
IP_CONFIG_VERSION := default
endif
endif
endif
endif
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
	@echo "IP CONFIG_FILE: $(call get_config_file_for_version,$(IP_CONFIG_VERSION))"
	@echo "VIVADO_IP :"
	@for ip in $(VIVADO_IP); do \
		echo "\t$$ip"; \
	done

.PHONY: .vivado_ip_info

endif # ifndef $(__CFG_VIVADO_IP_BASE_MK__)
