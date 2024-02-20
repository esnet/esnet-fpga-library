# This Makefile provides generic instructions for generating and
# managing Xilinx IP with Vivado.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
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
PROJ_NAME = ip_proj
PROJ_DIR = $(COMPONENT_OUT_PATH)/$(PROJ_NAME)

# -----------------------------------------------
# Command
# -----------------------------------------------
VIVADO_MANAGE_IP_CMD_BASE = $(VIVADO_CMD_BASE) -source $(VIVADO_SCRIPTS_ROOT)/manage_ip.tcl

VIVADO_MANAGE_IP_CMD = $(VIVADO_MANAGE_IP_CMD_BASE) -mode batch
VIVADO_MANAGE_IP_CMD_GUI = $(VIVADO_MANAGE_IP_CMD_BASE) -mode gui

# -----------------------------------------------
# Configure build options
# -----------------------------------------------
BUILD_JOBS ?= 4

# Format as optional arguments
BUILD_OPTIONS = \
    $(VIVADO_PART_CONFIG) \
    $(VIVADO_PROJ_CONFIG) \
    -jobs $(BUILD_JOBS) \
    $(foreach ip_tcl,$(IP_TCL_FILES),-ip_tcl $(ip_tcl)) \
    $(foreach ip_xci,$(IP_XCI_FILES),-ip_xci $(ip_xci))

# -----------------------------------------------
# Sources
# -----------------------------------------------
IP_TCL_FILES = $(addprefix $(IP_SRC_DIR)/,$(addsuffix .tcl,$(IP_LIST)))

# -----------------------------------------------
# Output products
# -----------------------------------------------
IP_XCI_FILES = $(foreach ip,$(IP_LIST),$(COMPONENT_OUT_PATH)/$(ip)/$(ip).xci)
IP_XCI_PROXY_FILES = $(foreach ip,$(IP_LIST),$(COMPONENT_OUT_PATH)/.xci/$(ip)/$(ip).xci)
IP_DCP_FILES = $(foreach ip,$(IP_LIST),$(COMPONENT_OUT_PATH)/$(ip)/$(ip).dcp)
IP_EXAMPLE_DESIGNS = $(foreach ip,$(IP_LIST),$(COMPONENT_OUT_PATH)/$(ip)_ex)

# -----------------------------------------------
# IP project targets
# -----------------------------------------------
# Create IP project in specified location to manage IP
_ip_proj_create: | $(PROJ_XPR)

# Launch IP project in GUI (for interactive inspection/modification of IP)
_ip_proj: $(PROJ_XPR)
	@make -s ip
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD_GUI) -tclargs gui $(BUILD_OPTIONS) &

_ip_proj_clean: _vivado_clean_logs
	@rm -rf $(IP_PROJ_DIR)

.PHONY: _ip_proj_create _ip_proj _ip_proj_clean

$(PROJ_XPR): | $(COMPONENT_OUT_PATH)
	@echo "----------------------------------------------------------"
	@echo "Creating IP project ($(COMPONENT_NAME)) ..."
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs create_proj $(BUILD_OPTIONS)
	@echo
	@echo "Done."

$(COMPONENT_OUT_PATH):
	@mkdir -p $@

# -----------------------------------------------
# IP creation targets
# -----------------------------------------------
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
	@mkdir -p $(COMPONENT_OUT_PATH)/.xci
	@cd $(COMPONENT_OUT_PATH)/.xci && $(VIVADO_MANAGE_IP_CMD) -tclargs create_ip $(BUILD_OPTIONS)
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
	@echo
	@echo "Done."

.PHONY: _ip

$(IP_XCI_PROXY_FILES): _ip_xci_proxy_files.intermediate ;

_ip_xci_proxy_files.intermediate: $(IP_TCL_FILES)
	@$(MAKE) -s ip

.INTERMEDIATE: _ip_xci_proxy_files.intermediate

$(IP_XCI_FILES): | $(IP_XCI_PROXY_FILES)

# -----------------------------------------------
# IP management targets
# -----------------------------------------------
# Generate IP example design
_ip_exdes: $(IP_EXAMPLE_DESIGNS)

# Reset IP output products
_ip_reset: ip | $(PROJ_XPR)
	@echo "----------------------------------------------------------"
	@echo "Reset IP output products ($(COMPONENT_NAME)) ..."
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs reset $(BUILD_OPTIONS)
	@echo
	@echo "Done."

# Report on IP status (version, upgrade availability, etc)
_ip_status: ip | $(PROJ_XPR)
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs status $(BUILD_OPTIONS)

# Upgrade IP
_ip_upgrade: ip | $(PROJ_XPR)
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs upgrade $(BUILD_OPTIONS)

# Compile IP
_ip_compile: _ip_sim_sources _compile_sim

# Synthesize IP
_ip_synth: $(IP_DCP_FILES) _ip_synth_sources

# Clean IP
_ip_clean: _vivado_clean_logs _ip_proj_clean _compile_clean
	@rm -rf $(COMPONENT_OUT_PATH)
	@-find $(OUTPUT_ROOT) -type d -empty -delete 2>/dev/null

.PHONY: _ip _ip_exdes _ip_reset _ip_status _ip_upgrade _ip_compile _ip_synth _ip_clean

# -----------------------------------------------
# Generate/manage synthesis products
# -----------------------------------------------
$(IP_DCP_FILES): _ip_dcp_files.intermediate ;

_ip_dcp_files.intermediate: $(IP_XCI_FILES) | $(PROJ_XPR)
	@echo "----------------------------------------------------------"
	@echo "Synthesize IP ($(COMPONENT_NAME)) ..."
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs synth $(BUILD_OPTIONS)
	@echo

.INTERMEDIATE: _ip_dcp_files.intermediate

_ip_synth_sources: | $(COMPONENT_OUT_SYNTH_PATH)
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

.PHONY: _ip_synth_sources

# -----------------------------------------------
# Generate/manage simulation sources
# -----------------------------------------------
__IP_SIM_SRC_FILES = $(addprefix $(COMPONENT_OUT_PATH)/,$(IP_SIM_SRC_FILES))
__IP_SIM_INC_DIRS = $(addprefix $(COMPONENT_OUT_PATH)/,$(IP_SIM_INC_DIRS))

$(__IP_SIM_SRC_FILES) $(__IP_SIM_INC_DIRS): _ip_sim_sources.intermediate ;

_ip_sim_sources.intermediate: $(IP_XCI_FILES) | $(PROJ_XPR)
	@echo "----------------------------------------------------------"
	@echo "Generate IP simulation output products ($(COMPONENT_NAME)) ..."
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs sim $(BUILD_OPTIONS)
	@echo
	@echo "Done."

_ip_sim_sources: $(__IP_SIM_SRC_FILES) $(__IP_SIM_INC_DIRS)

.INTERMEDIATE: _ip_sim_sources.intermediate

# Include source files and include directories
# as compile sources for sim
SRC_FILES += $(__IP_SIM_SRC_FILES)
INC_DIRS += $(__IP_SIM_INC_DIRS)

# -----------------------------------------------
# Generate IP example designs
# -----------------------------------------------
$(IP_EXAMPLE_DESIGNS): _ip_example_designs.intermediate ;

_ip_example_designs.intermediate: $(IP_XCI_FILES) | $(PROJ_XPR)
	@echo "----------------------------------------------------------"
	@echo "Generate IP example designs ($(COMPONENT_NAME)) ..."
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs exdes $(BUILD_OPTIONS)
	@echo
	@echo "Done."

.INTERMEDIATE: _ip_example_designs.intermediate

# -----------------------------------------------
# Info targets
# -----------------------------------------------
_ip_config_info: _vivado_info
	@echo "----------------------------------------------------------"
	@echo "Manage IP configuration"
	@echo "----------------------------------------------------------"
	@echo "SRC_ROOT            : $(SRC_ROOT)"
	@echo "IP_SRC_DIR          : $(IP_SRC_DIR)"
	@echo "PROJ_XPR            : $(PROJ_XPR)"
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
