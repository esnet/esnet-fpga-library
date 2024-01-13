# This Makefile provides generic instructions for generating and
# managing Xilinx IP with Vivado.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - IP_PROJ_DIR: path to managed IP project (optional, default: ./ip_proj)
#        - IP_PROJ_NAME: name of managed IP project (optional, default: ip_proj)
#        - SCRIPTS_ROOT: path to project scripts directory
#        - IP_SRC_DIR: path to IP specifications, in Tcl script format (optional, default: .)
#        - IP_LIST: list of IP to be included in project; each IP in IP_LIST corresponds
#                   to an IP specification Tcl file, available at: $(IP_SRC_DIR)/$(ip_name).tcl

# -----------------------------------------------
# Include base Vivado build Make instructions
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_base.mk

# -----------------------------------------------
# Include compile targets
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_compile.mk

# -----------------------------------------------
# Paths
# -----------------------------------------------
IP_SRC_DIR ?= $(CURDIR)
IP_OUT_DIR ?= $(COMPONENT_OUT_PATH)

# -----------------------------------------------
# Configure managed IP project properties
# -----------------------------------------------
# Export Make variables for use in Tcl scripts
export IP_PROJ_DIR ?= ip_proj
export IP_PROJ_NAME ?= ip_proj

# -----------------------------------------------
# Command
# -----------------------------------------------
VIVADO_LOG_DIR = $(IP_OUT_DIR)
VIVADO_MANAGE_IP_CMD = $(VIVADO_CMD_BASE) -source $(VIVADO_SCRIPTS_ROOT)/manage_ip.tcl

# -----------------------------------------------
# Output products
# -----------------------------------------------
IP_XCI_FILES = $(foreach ip,$(IP_LIST),$(IP_OUT_DIR)/$(ip)/$(ip).xci)
IP_VEO_FILES = $(foreach ip,$(IP_LIST),$(IP_OUT_DIR)/$(ip)/$(ip).veo)
IP_DCP_FILES = $(foreach ip,$(IP_LIST),$(IP_OUT_DIR)/$(ip)/$(ip).dcp)
IP_EXAMPLE_DESIGNS = $(foreach ip,$(IP_LIST),$(IP_OUT_DIR)/$(ip)_ex)

# -----------------------------------------------
# IP project targets
# -----------------------------------------------
#  IP project
#
#  - creates IP project in current directory to
#    facilitate creating/updating IP
#  - IP must be described as a 'create_ip' Tcl script, but
#    required Tcl commands for creating/modifying IP can
#    be copied from the 'Tcl Console' in the GUI
_ip_proj: _ip_proj_clean $(IP_XCI_FILES)
	@$(VIVADO_MANAGE_IP_CMD) -tclargs proj "{$(IP_XCI_FILES)}"

# Report on IP status (version, upgrade availability, etc)
_ip_status: _ip_create
	@cd $(IP_OUT_DIR) && $(VIVADO_MANAGE_IP_CMD) -tclargs status "{$(IP_XCI_FILES)}"

# Upgrade IP
_ip_upgrade: _ip_create
	@cd $(IP_OUT_DIR) && $(VIVADO_MANAGE_IP_CMD) -tclargs upgrade "{$(IP_XCI_FILES)}"

# Reset IP output products
_ip_reset: _ip_create
	@cd $(IP_OUT_DIR) && $(VIVADO_MANAGE_IP_CMD) -tclargs reset "{$(IP_XCI_FILES)}"

# Clean IP project
_ip_proj_clean: _vivado_clean_logs
	@-rm -rf $(IP_PROJ_DIR)
	@-rm -rf ip_user_files

.PHONY: _ip_proj _ip_status _ip_upgrade _ip_proj_clean

# -----------------------------------------------
# IP management targets
# -----------------------------------------------
# Create output directory as needed
$(IP_OUT_DIR):
	@mkdir -p $@

# Generate IP
_ip: _ip_generate

# Create IP
_ip_create: $(IP_XCI_FILES)

# Generate IP output products
_ip_generate: $(IP_VEO_FILES)

# Generate IP example design
_ip_exdes: $(IP_EXAMPLE_DESIGNS)

# Compile IP for simulation
_ip_compile: ip _compile_sim

# Synthesize IP
_ip_synth: ip $(IP_DCP_FILES)

# Clean IP
_ip_clean: _compile_clean _vivado_clean_logs
	@rm -rf $(IP_OUT_DIR)

.PHONY: _ip _ip_create _ip_generate _ip_exdes _ip_compile _ip_synth _ip_clean

# Generate explicit rules for each IP in IP_LIST.
#   - this is require to work around two challenges fitting the IP generation
#     process into a Makefile infrastructure:
#     (1) Vivado wants each IP to be located in an isolated directory for
#         output generation. This results in a target of IP_NAME/IP_NAME
#         which isn't easily supported using standard Makefile infrastructure
#         (wildcards only match first instance of pattern)
#     (2) IP output products are not the same 'shape'. Seems likely that the
#         instantiation template (veo file) could be used as a similar proxy,
#         but because it is created in the IP sub-directory (1) applies. Creating
#         proxy files (in the same directory) provides a convenient and consistent
#         way to reflect output product generation status.

# Create IP (generate XCI file from TCL specification)
define IP_CREATE_RULE
$(IP_OUT_DIR)/$(ip)/$(ip).xci: $(IP_SRC_DIR)/$(ip).tcl | $(IP_OUT_DIR)
	@rm -rf $(IP_OUT_DIR)/$(ip)
	@cd $(IP_OUT_DIR) && $(VIVADO_MANAGE_IP_CMD) -tclargs create $$<
endef
$(foreach ip,$(IP_LIST),$(eval $(IP_CREATE_RULE)))

# Generate IP (generate IP output products from XCI specification)
define IP_GENERATE_RULE
$(IP_OUT_DIR)/$(ip)/$(ip).veo: $(IP_OUT_DIR)/$(ip)/$(ip).xci
	@cd $(IP_OUT_DIR) && $(VIVADO_MANAGE_IP_CMD) -tclargs generate $$<
endef
$(foreach ip,$(IP_LIST),$(eval $(IP_GENERATE_RULE)))

# Generate IP example design (from XCI specification)
define IP_EXDES_RULE
$(IP_OUT_DIR)/$(ip)_ex: $(IP_OUT_DIR)/$(ip)/$(ip).xci
	@cd $(IP_OUT_DIR) && $(VIVADO_MANAGE_IP_CMD) -tclargs exdes $$<
endef
$(foreach ip,$(IP_LIST),$(eval $(IP_EXDES_RULE)))

# Synthesize IP out-of-context (generate DCP file from XCI specification)
define IP_SYNTH_RULE
$(IP_OUT_DIR)/$(ip)/$(ip).dcp: $(IP_OUT_DIR)/$(ip)/$(ip).xci
	@cd $(IP_OUT_DIR) && $(VIVADO_MANAGE_IP_CMD) -tclargs synth $$<
endef
$(foreach ip,$(IP_LIST),$(eval $(IP_SYNTH_RULE)))

# -----------------------------------------------
# Info targets
# -----------------------------------------------
_ip_config_info: _vivado_info
	@echo "----------------------------------------------------------"
	@echo "Manage IP Info"
	@echo "----------------------------------------------------------"
	@echo "SRC_ROOT            : $(SRC_ROOT)"
	@echo "IP_SRC_DIR          : $(IP_SRC_DIR)"
	@echo "IP_OUT_DIR          : $(IP_OUT_DIR)"
	@echo "OUTPUT_ROOT         : $(OUTPUT_ROOT)"
	@echo "IP_LIST             :"
	@for ip in $(IP_LIST); do \
		echo "\t$$ip"; \
	done
	@echo "IP_XCI_FILES        :"
	@for xci_file in $(IP_XCI_FILES); do \
		echo "\t$$xci_file"; \
	done
	@echo "IP_DCP_FILES        :"
	@for dcp_file in $(IP_DCP_FILES); do \
		echo "\t$$dcp_file"; \
	done

_ip_info: _vivado_info _ip_config_info _compile_info

.PHONY: ip_config_info _ip_info

