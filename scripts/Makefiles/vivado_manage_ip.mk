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
# Paths
# -----------------------------------------------
IP_SRC_DIR ?= $(CURDIR)

# -----------------------------------------------
# Configure managed IP project properties
# -----------------------------------------------
# Export Make variables for use in Tcl scripts
export IP_PROJ_NAME ?= ip_proj
export IP_PROJ_DIR ?= $(COMPONENT_OUT_PATH)/$(IP_PROJ_NAME)

IP_PROJ_XPR = $(IP_PROJ_DIR)/$(IP_PROJ_NAME).xpr

# -----------------------------------------------
# Command
# -----------------------------------------------
VIVADO_LOG_DIR = $(COMPONENT_OUT_PATH)
VIVADO_MANAGE_IP_CMD = $(VIVADO_CMD_BASE) -source $(VIVADO_SCRIPTS_ROOT)/manage_ip.tcl
VIVADO_MANAGE_IP_CMD_GUI = $(VIVADO_CMD_BASE_GUI) -source $(VIVADO_SCRIPTS_ROOT)/manage_ip.tcl

# -----------------------------------------------
# Sources
# -----------------------------------------------
IP_TCL_FILES = $(addprefix $(IP_SRC_DIR)/,$(addsuffix .tcl,$(IP_LIST)))

# -----------------------------------------------
# Output products
# -----------------------------------------------
IP_XCI_FILES = $(foreach ip,$(IP_LIST),$(COMPONENT_OUT_PATH)/$(ip)/$(ip).xci)
IP_DCP_FILES = $(foreach ip,$(IP_LIST),$(COMPONENT_OUT_PATH)/$(ip)/$(ip).dcp)
IP_EXAMPLE_DESIGNS = $(foreach ip,$(IP_LIST),$(COMPONENT_OUT_PATH)/$(ip)_ex)

# -----------------------------------------------
# IP project targets
# -----------------------------------------------
# Create IP project in specified location to manage IP
_ip_proj_create: | $(IP_PROJ_XPR)

# Launch IP project in GUI (for interactive inspection/modification of IP)
_ip_proj: $(IP_PROJ_XPR)
	@make -s ip
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD_GUI) -tclargs gui "{$(IP_XCI_FILES)}" &

_ip_proj_clean: _vivado_clean_logs
	@rm -rf $(IP_PROJ_DIR)

.PHONY: _ip_proj_create _ip_proj _ip_proj_clean

$(IP_PROJ_XPR): | $(COMPONENT_OUT_PATH)
	@echo "----------------------------------------------------------"
	@echo "Creating IP project ($(COMPONENT_NAME)) ..."
	@$(VIVADO_MANAGE_IP_CMD) -tclargs create_proj
	@echo
	@echo "Done."

# -----------------------------------------------
# Targets
# -----------------------------------------------
# Create IP
# - IP must be described as a 'create_ip' Tcl script
#   (required Tcl commands for creating/modifying IP can
#   be copied from the 'Tcl Console' in the GUI)
# - ip creation targets generate XCI descriptions of IP from Tcl scripts
# - XCI file is generated in a temp directory, and then compared
#   compared to the existing XCI file already tracked by the
#   manage IP project (if one exists)
# - if the XCI description has changed (for any reason, including
#   change to the underlying Tcl source, change to the Vivado version,
#   parameter change, etc.) the new XCI file replaces the existing one,
#   which most likely means that the downstream output products (simulation
#   files, synthesized DCP file, etc.) will need to be regenerated.
# - if the new XCI file is identical in content to the existing one, the
#   existing one is left as is (including timestamp). This prevents
#   unnecessary regeneration of existing output products.
_ip : | $(COMPONENT_OUT_PATH)
	@echo "----------------------------------------------------------"
	@echo "Create/update IP ($(COMPONENT_NAME)) ..."
	@rm -rf $(COMPONENT_OUT_PATH)/.xci
	@mkdir -p $(COMPONENT_OUT_PATH)/.xci
	@cd $(COMPONENT_OUT_PATH)/.xci && $(VIVADO_MANAGE_IP_CMD) -tclargs create_ip "{$(IP_TCL_FILES)}"
	@echo
	@echo "Update IP Summary:"
	@for ip in $(IP_LIST); do \
		echo -n "\t$$ip: "; \
		mkdir -p $(COMPONENT_OUT_PATH)/$$ip; \
		cmp -s $(COMPONENT_OUT_PATH)/.xci/$$ip/$$ip.xci $(COMPONENT_OUT_PATH)/$$ip/$$ip.xci; \
		retVal=$$?; \
		case $$retVal in \
			0) \
				echo "No change.";; \
			1) \
				cp $(COMPONENT_OUT_PATH)/.xci/$$ip/$$ip.xci $(COMPONENT_OUT_PATH)/$$ip/$$ip.xci; \
				echo "XCI updated.";; \
			2) \
				cp $(COMPONENT_OUT_PATH)/.xci/$$ip/$$ip.xci $(COMPONENT_OUT_PATH)/$$ip/$$ip.xci; \
				echo "XCI created.";; \
		esac \
	done
	@rm -rf $(COMPONENT_OUT_PATH)/.xci
	@echo
	@echo "Done."

# Generate IP example design
_ip_exdes: $(IP_EXAMPLE_DESIGNS)

# Reset IP output products
_ip_reset: ip | $(IP_PROJ_XPR)
	@echo "----------------------------------------------------------"
	@echo "Reset IP output products ($(COMPONENT_NAME)) ..."
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs reset "{$(IP_XCI_FILES)}"
	@echo
	@echo "Done."

# Report on IP status (version, upgrade availability, etc)
_ip_status: ip | $(IP_PROJ_XPR)
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs status "{$(IP_XCI_FILES)}"

# Upgrade IP
_ip_upgrade: ip | $(IP_PROJ_XPR)
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs upgrade "{$(IP_XCI_FILES)}"

# Compile IP
_ip_compile: _compile_sim

# Synthesize IP
_ip_synth: ip | $(IP_PROJ_XPR) $(COMPONENT_OUT_SYNTH_PATH)
	@echo "----------------------------------------------------------"
	@echo "Synthesize IP ($(COMPONENT_NAME)) ..."
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs synth "{$(IP_XCI_FILES)}"
	@echo
	@echo "----------------------------------------------------------"
	@echo "Compiling synthesis library '$(COMPONENT_NAME)' ..."
	@echo
	@-rm -rf $(COMPONENT_OUT_SYNTH_PATH)/*.f
	@echo "# =====================================================" > $(SYNTH_SOURCES_OBJ)
	@echo "# Source listing for $(COMPONENT_NAME)" >> $(SYNTH_SOURCES_OBJ)
	@echo "#" >> $(SYNTH_SOURCES_OBJ)
	@echo "# NOTE: This file is autogenerated. DO NOT EDIT." >> $(SYNTH_SOURCES_OBJ)
	@echo "# =====================================================" >> $(SYNTH_SOURCES_OBJ)
	@echo >> $(SYNTH_SOURCES_OBJ)
	@echo "# Xilinx IP source listing" >> $(SYNTH_SOURCES_OBJ)
	@echo "# ------------------------" >> $(SYNTH_SOURCES_OBJ)
	@rm -rf $(COMPONENT_OUT_SYNTH_PATH)/*.f
	@-for xcifile in $(abspath $(IP_XCI_FILES)); do \
		echo $$xcifile >> $(COMPONENT_OUT_SYNTH_PATH)/ip_srcs.f; \
		echo "read_ip -quiet $$xcifile" >> $(SYNTH_SOURCES_OBJ); \
	done
	@echo >> $(SYNTH_SOURCES_OBJ)
	@echo "Done."

# Clean IP
_ip_clean: _vivado_clean_logs _ip_proj_clean _compile_clean
	@rm -rf $(COMPONENT_OUT_PATH)
	@-find $(OUTPUT_ROOT) -type d -empty -delete 2>/dev/null

.PHONY: _ip _ip_exdes _ip_reset _ip_status _ip_upgrade _ip_compile _ip_synth _ip_clean

$(IP_XCI_FILES): $(IP_TCL_FILES)
	@$(MAKE) -s ip

# -----------------------------------------------
# Generate/manage simulation sources
# -----------------------------------------------
__IP_SIM_SRC_FILES = $(addprefix $(COMPONENT_OUT_PATH)/,$(IP_SIM_SRC_FILES))
__IP_SIM_INC_DIRS = $(addprefix $(COMPONENT_OUT_PATH)/,$(IP_SIM_INC_DIRS))

$(__IP_SIM_SRC_FILES) $(__IP_SIM_INC_DIRS): $(IP_XCI_FILES) | $(IP_PROJ_XPR)
	@make -s ip
	@echo "----------------------------------------------------------"
	@echo "Generate IP simulation output products ($(COMPONENT_NAME)) ..."
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs sim "{$(IP_XCI_FILES)}"
	@echo
	@echo "Done."

# Include source files and include directories
# as compile sources for sim
SRC_FILES += $(__IP_SIM_SRC_FILES)
INC_DIRS += $(__IP_SIM_INC_DIRS)

# -----------------------------------------------
# Generate IP example designs
# -----------------------------------------------
$(IP_EXAMPLE_DESIGNS): $(IP_XCI_FILES) | $(IP_PROJ_XPR)
	@make -s ip
	@echo "----------------------------------------------------------"
	@echo "Generate IP example designs ($(COMPONENT_NAME)) ..."
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs exdes "{$(IP_XCI_FILES)}"
	@echo
	@echo "Done."

# -----------------------------------------------
# Info targets
# -----------------------------------------------
_ip_config_info: _vivado_info
	@echo "----------------------------------------------------------"
	@echo "Manage IP configuration"
	@echo "----------------------------------------------------------"
	@echo "SRC_ROOT            : $(SRC_ROOT)"
	@echo "IP_SRC_DIR          : $(IP_SRC_DIR)"
	@echo "IP_PROJ_XPR         : $(IP_PROJ_XPR)"
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
	@echo "IP_SIM_SRC_FILES    :"
	@for src_file in $(__IP_SIM_SRC_FILES); do \
		echo "\t$$src_file"; \
	done
	@echo "IP_INC_DIRS         :"
	@for inc_dir in $(__IP_SIM_INC_DIRS); do \
		echo "\t$$inc_dir"; \
	done
	@echo "IP_EXAMPLE_DESIGNS  :"
	@for ex_des in $(IP_EXAMPLE_DESIGNS); do \
		echo "\t$$ex_des"; \
	done

_ip_info: _ip_config_info _compile_info

.PHONY: ip_config_info _ip_info

# -----------------------------------------------
# Include compile targets
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_compile.mk
