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

# -----------------------------------------------
# Include component config
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/component_base.mk

# -----------------------------------------------
# Configure managed IP project properties
# -----------------------------------------------
# Export Make variables for use in Tcl scripts
export IP_PROJ_DIR ?= ip_proj
export IP_PROJ_NAME ?= ip_proj

# -----------------------------------------------
# Command
# -----------------------------------------------
VIVADO_MANAGE_IP_CMD = $(VIVADO_CMD_BASE) -source $(VIVADO_SCRIPTS_ROOT)/manage_ip.tcl
VIVADO_LOG_DIR = $(COMPONENT_OUT_PATH)

# -----------------------------------------------
# IP Sources
# -----------------------------------------------
IP_SRC_DIR ?= .
XCI_FILES = $(join $(addsuffix /,$(IP_LIST)),$(addsuffix .xci,$(IP_LIST)))

# -----------------------------------------------
# Output products
# -----------------------------------------------
IP_OUTPUT_PRODUCTS = $(addprefix $(COMPONENT_OUT_PATH)/.ip__,$(IP_LIST))
SYNTH_OUTPUT_PRODUCTS = $(addprefix $(COMPONENT_OUT_PATH)/.synth__,$(IP_LIST))

# -----------------------------------------------
# IP project targets
# -----------------------------------------------
#  IP project
#
#  - creates IP project in current directory
#  - can be used to create and edit IP
_ip_proj: _ip_proj_clean
	@$(VIVADO_MANAGE_IP_CMD) -tclargs create "{$(addprefix $(IP_SRC_DIR)/,$(XCI_FILES))}"
	@echo "# Ignore everything in IP directories except xci files" > .gitignore
	@echo ".gitignore" >> .gitignore
	@echo "*/*" >> .gitignore
	@echo "!*/*.xci" >> .gitignore

_ip_status:
	@$(VIVADO_MANAGE_IP_CMD) -tclargs status "{$(addprefix $(IP_SRC_DIR)/,$(XCI_FILES))}"
	@rm -rf .Xil

_ip_upgrade:
	@$(VIVADO_MANAGE_IP_CMD) -tclargs upgrade "{$(addprefix $(IP_SRC_DIR)/,$(XCI_FILES))}"
	@rm -rf .Xil

# Clean IP project
# - in addition to removing project directory need to also 'clean' individual IP
#   directories; this is somewhat challenging due to the default Vivado behaviour
#   where the output products are generated in the same directory as the source
#   (i.e. xci). Assume (for now at least) that all non-XCI files are generated
#   files and should be deleted.
_ip_proj_clean: _clean_logs
	@rm -rf $(IP_PROJ_DIR)
	@rm -rf ip_user_files
	@rm -rf hbs
	@rm -rf .gitignore
	@-for ip in $(IP_LIST); do \
		find ./$$ip -type f -not -name "*.xci" -delete 2>/dev/null; \
		find ./$$ip -type d -empty -delete 2>/dev/null; \
	done

.PHONY: _ip_proj _ip_status _ip_upgrade _ip_proj_clean

# -----------------------------------------------
# IP management targets
# -----------------------------------------------

# Create output directory; include back link to source directory
$(COMPONENT_OUT_PATH):
	@mkdir -p $(COMPONENT_OUT_PATH)
	@ln -s $(shell pwd) $(COMPONENT_OUT_PATH)/source

# Generate IP output products
_ip: $(IP_OUTPUT_PRODUCTS)
.PHONY: _ip

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
# NOTE: invoke SECONDEXPANSION here to allow dependencies to reflect that source IP
#       are located in separate directories. See (1) above. SECONDEXPANSION allows
#       the dependency to be specified using the pattern matching results from the
#       first expansion, to support dependencies in the form ip_name/ip_name.xci.
.SECONDEXPANSION:
$(COMPONENT_OUT_PATH)/.ip__%: $(IP_SRC_DIR)/$$*/$$*.xci
	@rm -f $@
	@mkdir -p $(COMPONENT_OUT_PATH)/$*
ifneq ($(COMPONENT_OUT_PATH),$(IP_SRC_DIR))
	@-cp $< $(COMPONENT_OUT_PATH)/$*/$*.xci
endif
	@cd $(COMPONENT_OUT_PATH)/$* && $(VIVADO_MANAGE_IP_CMD) -tclargs generate $*.xci
	@touch $@

# Synthesize IP
_ip_synth: $(SYNTH_OUTPUT_PRODUCTS)
.PHONY: _ip_synth

$(COMPONENT_OUT_PATH)/.synth__% : $(COMPONENT_OUT_PATH)/.ip__%
	@rm -f $@
	@cd $(COMPONENT_OUT_PATH)/$* && $(VIVADO_MANAGE_IP_CMD) -tclargs synth $*.xci
	@touch $@

# Clean
#   - remove all output products
_ip_clean: _clean_logs
	@rm -f $(COMPONENT_OUT_PATH)/source
	@rm -rf $(COMPONENT_OUT_PATH)
	@-find $(IP_OUT_ROOT) -type d -empty -delete 2>/dev/null

.PHONY: _ip_clean
