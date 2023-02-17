# -----------------------------------------------------------------------------
# Part config Makefile snippet
#
#  Provides standardized configuration of Vivado, including version and
#  license checks.
#
#  Expected to be included in a parent Makefile, where the following variables
#  are defined:
#
#  CFG_ROOT - path to configuration directory.
# -----------------------------------------------------------------------------
# Include configuration settings
include $(CFG_ROOT)/vivado.mk

# Check that configured Vivado version matches supported Vivado version
vivado_version_check:
ifndef XILINX_VIVADO
	$(error Vivado not configured. Expecting Vivado v$(VIVADO_VERSION__WITH_PATCHES))
else
ifneq ($(notdir $(XILINX_VIVADO)), $(VIVADO_VERSION))
	$(error Vivado $(VIVADO_VERSION__WITH_PATCHES) not configured (found Vivado $(notdir $(XILINX_VIVADO))))
else
	@$(if $(filter $(VIVADO_VERSION__WITH_PATCHES),$(__CONFIGURED_VIVADO_VERSION)),:,$(__print_patch_mismatch_warning))
endif
endif

# Query tool for full (i.e. patched) version
__CONFIGURED_VIVADO_VERSION = $(shell vivado -version | sed -rn '1s/.*([0-9]{4}\.[0-9]([\._][0-9a-zA-Z_]+)?).*/\1/pg')

# Warning for mismatched Vivado patch versions, i.e. 2022.1 =/= 2022.1.1, 2022.1.1 =/= 2022.1.1_AR88888, etc.
__print_patch_mismatch_warning = \
	echo "WARNING: The currently-configured Vivado version differs in patch revision from the supported Vivado version."; \
	echo ""; \
	echo "    Supported:  Vivado $(VIVADO_VERSION__WITH_PATCHES)"; \
	echo "    Configured: Vivado $(__CONFIGURED_VIVADO_VERSION)"; \
	echo ""; \
	echo "    The configured version of Vivado *should* work with this repository, since in general"; \
	echo "    releases with the same major/minor revision are expected to be compatible."; \
	echo "    However, it is recommended to use the supported version, including patch revision."; \
    echo "";

# Execute Vivado to check on license status for specified IP
vivado_license_check:
	@vivado -mode batch -nolog -nojournal -notrace -source $(SCRIPTS_ROOT)/vivado/check_ip_license.tcl -tclargs $(LICENSED_IP) || echo "ERROR: Xilinx IP license check failed"

vivado_check: vivado_version_check vivado_license_check

.PHONY: vivado_version_check vivado_license_check vivado_check

