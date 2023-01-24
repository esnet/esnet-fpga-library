# This Makefile provides generic instructions for generating and
# managing Xilinx IP with Vivado.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - SCRIPTS_ROOT: path to project scripts directory
#        - IP_PROJ_DIR: path to managed IP project (optional, default: ./ip_proj)
#        - IP_PROJ_NAME: name of managed IP project (optional, default: ip_proj)
#        - IP_LIST: list of IP to be included in project; each IP in IP_LIST represents
#                   the name of an IP directory, where the IP directory contains an
#                   .xci file describing the IP
#        - VITISNETP4_IP_NAME: name of vitisnetp4 ip component to be created
#        - VITISNETP4_IP_DIR: location in which to create vitisnetp4 ip component
#        - P4_FILE: path to p4 file describing vitisnetp4 component functionality
#        - P4_OPTS: (optional) dictionary of options to pass to the P4 compiler

# Default IP location is output directory
VITISNETP4_IP_DIR ?= $(COMPONENT_OUT_PATH)

# Set IP source directory for manage IP targets
IP_SRC_DIR = $(VITISNETP4_IP_DIR)

# -----------------------------------------------
# Command
# -----------------------------------------------
VIVADO_VITISNETP4_CMD = $(VIVADO_CMD_BASE) -source $(VIVADO_SCRIPTS_ROOT)/vitisnetp4.tcl

# -----------------------------------------------
# Source files
# -----------------------------------------------
VITISNETP4_XCI_DIR = $(abspath $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME))
VITISNETP4_XCI_FILE = $(VITISNETP4_XCI_DIR)/$(VITISNETP4_IP_NAME).xci

VITISNETP4_DRV_DPI_DIR = $(VITISNETP4_XCI_DIR)
VITISNETP4_DRV_DPI_LIB = vitisnetp4_drv_dpi
VITISNETP4_DRV_DPI_FILE = $(VITISNETP4_DRV_DPI_DIR)/$(VITISNETP4_DRV_DPI_LIB).so

VITISNETP4_EXDES_DIR = $(VITISNETP4_XCI_DIR)_ex
VITISNETP4_EXDES_PKG = $(VITISNETP4_EXDES_DIR)/imports/example_design_pkg.sv

# -----------------------------------------------
# Options
# -----------------------------------------------
DEFAULT_P4_OPTS =
P4_OPTS += $(DEFAULT_P4_OPTS)

# -----------------------------------------------
# Targets
# -----------------------------------------------
_vitisnetp4_params:
	@echo "=============================================================================="
	@echo "Parameters"
	@echo "=============================================================================="
	@echo "SCRIPTS_ROOT:       $(SCRIPTS_ROOT)"
	@echo "VITISNETP4_IP_NAME: $(VITISNETP4_IP_NAME)"
	@echo "VITISNETP4_IP_DIR:  $(VITISNETP4_IP_DIR)"
	@echo "P4_FILE:            $(P4_FILE)"
	@echo "P4_OPTS:            $(P4_OPTS)"

_vitisnetp4: $(VITISNETP4_XCI_FILE)

_vitisnetp4_drv_dpi: $(VITISNETP4_DRV_DPI_FILE)

_vitisnetp4_exdes: $(VITISNETP4_EXDES_PKG)

_vitisnetp4_clean:
	@rm -rf $(VITISNETP4_XCI_DIR)

.PHONY: _vitisnetp4_params _vitisnetp4 _vitisnetp4_drv_dpi _vitisnetp4_clean

$(VITISNETP4_XCI_FILE): $(P4_FILE) | $(VITISNETP4_IP_DIR)
	@-rm -rf $(VITISNETP4_XCI_DIR)
	@$(VIVADO_VITISNETP4_CMD) -tclargs create $(VITISNETP4_IP_NAME) $(P4_FILE) "$(P4_OPTS)" $(VITISNETP4_IP_DIR)

$(VITISNETP4_DRV_DPI_FILE): $(VITISNETP4_XCI_FILE)
	@$(VIVADO_VITISNETP4_CMD) -tclargs drv_dpi $(VITISNETP4_IP_NAME) $(VITISNETP4_IP_DIR) $(VITISNETP4_DRV_DPI_DIR)

$(VITISNETP4_EXDES_PKG): $(VITISNETP4_XCI_FILE)
	@-rm -rf $(VITISNETP4_EXDES_DIR)
	@$(VIVADO_VITISNETP4_CMD) -tclargs exdes $(VITISNETP4_IP_NAME) $(VITISNETP4_IP_DIR)

# -----------------------------------------------
# Include base Vivado IP management Make instructions
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_manage_ip.mk

