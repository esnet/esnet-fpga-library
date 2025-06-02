ifndef __CFG_VIVADO_BASE_MK__
__CFG_VIVADO_BASE_MK__ := defined
# -----------------------------------------------
# This Makefile provides generic definitions for querying
# the vivado tool for version information
#
# Usage: this Makefile is used by including it from a 'parent' Makefile,
#        where the parent can call the targets defined here
# -----------------------------------------------
# Query tool for full version
VIVADO_ACTIVE_VERSION = $(shell vivado -version | sed -rn '1s/.*([0-9]{4}\.[0-9]([\._][0-9a-zA-Z_]+)?).*/\1/pg')

# Function for extracting major version from full version
get_vivado_major_version = $(shell echo $(1) | sed -rn '1s/([0-9]{4}\.[0-9]).*/\1/pg')
get_vivado_major_minor_version = $(shell echo $(1) | sed -rn '1s/([0-9]{4}\.[0-9]\.?[0-9]?).*/\1/pg')

PROJ_VIVADO_VERSION__MAJOR = $(call get_vivado_major_version,$(PROJ_VIVADO_VERSION))
PROJ_VIVADO_VERSION__MAJOR_MINOR = $(call get_vivado_major_minor_version,$(PROJ_VIVADO_VERSION))
VIVADO_ACTIVE_VERSION__MAJOR = $(notdir $(XILINX_VIVADO))
VIVADO_ACTIVE_VERSION__MAJOR_MINOR = $(call get_vivado_major_minor_version,$(VIVADO_ACTIVE_VERSION))

# Warning for mismatched Vivado patch versions, i.e. 2022.1 =/= 2022.1.1, 2022.1.1 =/= 2022.1.1_AR88888, etc.
__print_patch_mismatch_warning = \
	echo "WARNING: The currently-active Vivado version differs in minor or patch revision from the supported Vivado version."; \
	echo ""; \
	echo "    Supported:  Vivado $(PROJ_VIVADO_VERSION)"; \
	echo "    Configured: Vivado $(VIVADO_ACTIVE_VERSION)"; \
	echo ""; \
	echo "    The active version of Vivado *should* work with this repository, since in general"; \
	echo "    releases with the same major revision are expected to be compatible."; \
	echo "    However, it is recommended to use the supported version, including minor (and patch) revision."; \
    echo "";

# -----------------------------------------------
# Targets
# -----------------------------------------------
# Tool version check
.vivado_version_check:
ifndef XILINX_VIVADO
	$(error Vivado not configured. Expecting Vivado v$(PROJ_VIVADO_VERSION))
else
ifneq ($(notdir $(XILINX_VIVADO)), $(PROJ_VIVADO_VERSION__MAJOR))
	$(info  *** This project expects Vivado $(PROJ_VIVADO_VERSION) (found Vivado $(notdir $(XILINX_VIVADO))). ***)
	$(info  To continue using Vivado $(notdir $(XILINX_VIVADO)) (unsupported), change the project version specified in $(abspath $(CFG_ROOT)/vivado.mk).)
	$(error Invalid Vivado tool version)
else
	@$(if $(filter $(PROJ_VIVADO_VERSION),$(VIVADO_ACTIVE_VERSION)),echo "Vivado $(PROJ_VIVADO_VERSION) in use; matches version supported by project.",$(__print_patch_mismatch_warning))
endif
endif

.PHONY: .vivado_version_check

# Display tool version information
.vivado_version_info:
	@echo "---------------------------------------------------------"
	@echo "(Vivado) tool version (expected, as supported by project)"
	@echo "---------------------------------------------------------"
	@echo "PROJ_VIVADO_VERSION               : $(PROJ_VIVADO_VERSION)"
	@echo "PROJ_VIVADO_VERSION (MAJOR/MINOR) : $(PROJ_VIVADO_VERSION__MAJOR_MINOR)"
	@echo "PROJ_VIVADO_VERSION (MAJOR)       : $(PROJ_VIVADO_VERSION__MAJOR)"
	@echo "---------------------------------------------------------"
	@echo "(Vivado) tool version (active, as configured on system)"
	@echo "---------------------------------------------------------"
	@echo "VIVADO_ACTIVE_VERSION               : $(VIVADO_ACTIVE_VERSION)"
	@echo "VIVADO_ACTIVE_VERSION (MAJOR/MINOR) : $(VIVADO_ACTIVE_VERSION__MAJOR_MINOR)"
	@echo "VIVADO_ACTIVE_VERSION (MAJOR)       : $(VIVADO_ACTIVE_VERSION__MAJOR)"

.PHONY: .vivado_version_info

endif # ifndef $(__CFG_VIVADO_BASE_MK__)
