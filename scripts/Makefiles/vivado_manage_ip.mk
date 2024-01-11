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

# -----------------------------------------------
# Configure managed IP project properties
# -----------------------------------------------
# Export Make variables for use in Tcl scripts
export IP_PROJ_DIR ?= ip_proj
export IP_PROJ_NAME ?= ip_proj

# -----------------------------------------------
# Command
# -----------------------------------------------
VIVADO_LOG_DIR = $(COMPONENT_OUT_PATH)
VIVADO_MANAGE_IP_CMD = $(VIVADO_CMD_BASE) -source $(VIVADO_SCRIPTS_ROOT)/manage_ip.tcl

# -----------------------------------------------
# Output products
# -----------------------------------------------
IP_XCI_FILES = $(foreach ip,$(IP_LIST),$(COMPONENT_OUT_PATH)/$(ip)/$(ip).xci)

IP_OUTPUT_PRODUCTS   = $(addprefix $(COMPONENT_OUT_PATH)/.ip__,$(IP_LIST))
IP_GENERATE_PRODUCTS = $(addsuffix __generated, $(IP_OUTPUT_PRODUCTS))
IP_EXDES_PRODUCTS    = $(addsuffix __exdes, $(IP_OUTPUT_PRODUCTS))
IP_DRV_DPI_PRODUCTS  = $(addsuffix __drv_dpi, $(IP_OUTPUT_PRODUCTS))
IP_SYNTH_PRODUCTS    = $(addsuffix __synth, $(IP_OUTPUT_PRODUCTS))

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
_ip_proj: _ip_proj_clean $(IP_OUTPUT_PRODUCTS)
	@$(VIVADO_MANAGE_IP_CMD) -tclargs proj "{$(IP_XCI_FILES)}"

# Clean IP project
_ip_proj_clean: _vivado_clean_logs
	@-rm -rf $(IP_PROJ_DIR)
	@-rm -rf ip_user_files

.PHONY: _ip_proj _ip_proj_clean

# -----------------------------------------------
# IP management targets
# -----------------------------------------------
# Create output directory as needed
$(COMPONENT_OUT_PATH):
	@mkdir -p $@

# Generate IP output products
_ip: _ip_generate

.PHONY: _ip

# Compile IP
_ip_compile: _ip _compile

.PHONY: _ip_compile

# Create dot-files per IP as proxy for generated output products
#   - this works around two challenges fitting the IP generation process
#     into a Makefile infrastructure:
#     (1) Vivado wants each IP to be located in an isolated directory for
#         output generation. This results in a target of IP_NAME/IP_NAME
#         which isn't easily supported using standard Makefile infrastructure
#         (wildcards only match first instance of pattern)
#     (2) IP output products are not the same 'shape'. Seems likely that the
#         instantiation template (veo file) could be used as a similar proxy,
#         but because it is created in the IP sub-directory (1) applies. Creating
#         proxy files (in the same directory) provides a convenient and consistent
#         way to reflect output product generation status.
$(COMPONENT_OUT_PATH)/.ip__%: $(abspath $(IP_SRC_DIR)/%.tcl) | $(COMPONENT_OUT_PATH)
	@rm -f $@*
	@rm -rf $(COMPONENT_OUT_PATH)/$*
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs create $<
	@touch $@

$(COMPONENT_OUT_PATH)/.ip__%__exdes: $(COMPONENT_OUT_PATH)/.ip__%
	@rm -f $@
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs exdes $*/$*.xci
	@touch $@

$(COMPONENT_OUT_PATH)/.ip__%__drv_dpi: $(COMPONENT_OUT_PATH)/.ip__%
	@rm -f $@
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs drv_dpi $*/$*.xci
	@touch $@

$(COMPONENT_OUT_PATH)/.ip__%__generated: $(COMPONENT_OUT_PATH)/.ip__%
	@rm -f $@
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs reset $*/$*.xci
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs generate $*/$*.xci
	@touch $@

$(COMPONENT_OUT_PATH)/.ip__%__synth : $(COMPONENT_OUT_PATH)/.ip__%__generated
	@rm -f $@
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs synth $*/$*.xci
	@touch $@

# Create IP
_ip_create: $(IP_OUTPUT_PRODUCTS)

# Generate IP output products
_ip_generate: $(IP_GENERATE_PRODUCTS)

# Reset IP output products
_ip_reset: _ip_create
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs reset "{$(IP_XCI_FILES)}"
	@-rm $(COMPONENT_OUT_PATH)/.ip__*__generated

# Report on IP status (version, upgrade availability, etc)
_ip_status: _ip_create
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs status "{$(IP_XCI_FILES)}"

# Upgrade IP
_ip_upgrade: _ip_create
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs upgrade "{$(IP_XCI_FILES)}"

# Synthesize IP
_ip_synth: $(IP_SYNTH_PRODUCTS)

.PHONY: _ip_create _ip_generate _ip_reset _ip_status _ip_upgrade _ip_synth

# Clean
_ip_clean: _clean_compile _vivado_clean_logs
	@rm -rf $(COMPONENT_OUT_PATH)

.PHONY: _ip_clean
