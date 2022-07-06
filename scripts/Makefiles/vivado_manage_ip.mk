# This Makefile provides generic instructions for generating and
# managing Xilinx IP with Vivado.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - IP_PROJ_DIR: path to managed IP project (optional, default: ./ip_proj)
#        - IP_PROJ_NAME: name of managed IP project (optional, default: ip_proj)
#        - SCRIPTS_ROOT: path to project scripts directory
#        - IP_LIST: list of IP to be included in project; each IP in IP_LIST represents
#                   the name of an IP directory, where the IP directory contains an
#                   .xci file describing the IP

# -----------------------------------------------
# Include base Vivado build Make instructions
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_build_base.mk

# Export Make variables for use in Tcl scripts
export IP_PROJ_DIR ?= ip_proj
export IP_PROJ_NAME ?= ip_proj

# -----------------------------------------------
# Command
# -----------------------------------------------
VIVADO_MANAGE_IP_CMD = $(VIVADO_CMD_BASE) -source $(VIVADO_SCRIPTS_ROOT)/manage_ip.tcl

# -----------------------------------------------
# Source files
# -----------------------------------------------
XCI_FILES = $(foreach ip,$(IP_LIST),$(ip)/$(notdir $(ip)).xci)
VEO_FILES = $(XCI_FILES:.xci=.veo)
DCP_FILES = $(XCI_FILES:.xci=.dcp)

# -----------------------------------------------
# Defines
# -----------------------------------------------
IP_PROJ_FILE = $(IP_PROJ_DIR)/$(IP_PROJ_NAME).xpr

# -----------------------------------------------
# Targets
# -----------------------------------------------
_ip: _ip_import
.PHONY: _ip

_ip_proj: $(IP_PROJ_FILE)
.PHONY: _ip_proj

_ip_import: $(VEO_FILES)
.PHONY: _ip_import

_ip_synth: $(DCP_FILES)
.PHONY: _ip_synth

_ip_reset: _ip_proj
	$(VIVADO_MANAGE_IP_CMD) -tclargs reset

_ip_status: _ip_proj
	$(VIVADO_MANAGE_IP_CMD) -tclargs status
	
$(IP_PROJ_FILE):
	$(VIVADO_MANAGE_IP_CMD) -tclargs create

%.dcp : %.xci | _ip_import
	$(VIVADO_MANAGE_IP_CMD) -tclargs synth $(notdir $(basename $<))

%.veo : %.xci | _ip_proj
	$(VIVADO_MANAGE_IP_CMD) -tclargs import $<
	$(VIVADO_MANAGE_IP_CMD) -tclargs generate all $(notdir $*)
	@touch $@

_ip_proj_clean: _clean_logs
	@rm -rf $(IP_PROJ_DIR)
	@rm -f $(VEO_FILES)
	@rm -rf ip_user_files
	@rm -rf hbs
