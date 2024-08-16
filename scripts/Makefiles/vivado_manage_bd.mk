# This Makefile provides generic instructions for generating and
# managing Xilinx Block Designs (BDs) with Vivado.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - SCRIPTS_ROOT: path to project scripts directory
#        - BD_SRC_DIR: path to block design (BD) specifications, in Tcl script format (optional, default: .)
#        - BD_LIST: list of block designs to be included in project; each BD in BD_LIST corresponds
#                   to a BD specification Tcl file, available at: $(BD_SRC_DIR)/$(BD).tcl

# -----------------------------------------------
# Include base Vivado build Make instructions
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_base.mk

# -----------------------------------------------
# Paths
# -----------------------------------------------
BD_SRC_DIR ?= $(CURDIR)

# -----------------------------------------------
# Configure managed IP project properties
# -----------------------------------------------
PROJ_NAME = bd_proj
PROJ_DIR = $(COMPONENT_OUT_PATH)/$(PROJ_NAME)

# -----------------------------------------------
# Command
# -----------------------------------------------
VIVADO_MANAGE_BD_CMD_BASE = $(VIVADO_CMD_BASE) -source $(VIVADO_SCRIPTS_ROOT)/manage_bd.tcl

VIVADO_MANAGE_BD_CMD = $(VIVADO_MANAGE_BD_CMD_BASE) -mode batch
VIVADO_MANAGE_BD_CMD_GUI = $(VIVADO_MANAGE_BD_CMD_BASE) -mode gui

# -----------------------------------------------
# Configure build options
# -----------------------------------------------
BUILD_JOBS ?= 4

# Format as optional arguments
BUILD_OPTIONS = \
    $(VIVADO_PROJ_CONFIG) \
    $(VIVADO_PART_CONFIG) \
    $(foreach bd,$(BD_LIST),-bd $(bd)) \
	$(foreach iprepo,$(IP_REPO_PATHS),-ip_repo $(iprepo)) \
    -jobs $(BUILD_JOBS)

# -----------------------------------------------
# Sources
# -----------------------------------------------
BD_TCL_FILES = $(addprefix $(BD_SRC_DIR)/,$(addsuffix .tcl,$(BD_LIST)))

# -----------------------------------------------
# Output products
# -----------------------------------------------
BD_FILES = $(foreach bd,$(BD_LIST),$(COMPONENT_OUT_PATH)/$(bd)/$(bd).bd)
BD_DCP_FILES = $(foreach bd,$(BD_LIST),$(PROJ_DIR)/$(PROJ_NAME).runs/$(bd)_synth_1/$(bd).dcp)

BD_PROXY_DIR = $(COMPONENT_OUT_PATH)/.bd
BD_PROXY_FILES = $(foreach bd,$(BD_LIST),$(BD_PROXY_DIR)/$(bd)/$(bd).bd)
BD_PROXY_REFRESH_FILES = $(foreach bd,$(BD_LIST),$(BD_PROXY_DIR)/.refresh__$(bd))

# -----------------------------------------------
# BD project targets
# -----------------------------------------------
# Create BD project in specified location
_bd_proj_create: | $(PROJ_XPR)

# Launch IP project in GUI (for interactive inspection/modification of IP)
_bd_proj: $(PROJ_XPR)
	@make -s bd
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_BD_CMD_GUI) -tclargs gui $(BUILD_OPTIONS) &

_bd_proj_clean: _vivado_clean_logs
	@rm -rf $(PROJ_DIR)

.PHONY: _bd_proj_create _bd_proj _bd_proj_clean

$(PROJ_XPR): | $(COMPONENT_OUT_PATH)
	@echo "----------------------------------------------------------"
	@echo "Creating BD project ($(COMPONENT_NAME)) ..."
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_BD_CMD) -tclargs create_proj $(BUILD_OPTIONS)
	@echo
	@echo "Done."

$(COMPONENT_OUT_PATH):
	@mkdir -p $@

# -----------------------------------------------
# BD creation targets
# -----------------------------------------------
# - BD must be described as a 'create_bd_design' Tcl script
#   (required Tcl commands for creating/modifying BD can
#   be copied from the 'Tcl Console' in the GUI)
# - creation targets generate BD files
# - BD file is generated in a temp directory, and then compared
#   to the existing BD file already tracked by the project (if one exists)
# - if the BD has changed (for any reason, including change to the
#   underlying Tcl source, change to the Vivado version,
#   parameter change, etc.) the new BD file replaces the existing one,
#   which most likely means that the downstream output products (simulation
#   files, synthesized DCP file, etc.) will need to be regenerated.
# - if the new BD file is identical in content to the existing one, the
#   existing one is left as is (including timestamp). This prevents
#   unnecessary regeneration of existing output products.
_bd: $(BD_PROXY_DIR)/.refreshed

# Schedule BD refresh
_bd_refresh: | $(BD_PROXY_DIR)
	@touch $(BD_PROXY_DIR)/.refresh

.PHONY: _bd _bd_refresh

# Create BD proxy directory as needed
$(BD_PROXY_DIR):
	@mkdir -p $@

# Define rules for each BD determining when that BD needs to be created or updated.
# The BD should be created when it doesn't exist; it should additionally be regenerated
# every time the source (Tcl) is updated, and when an explicit request has been made
# to update the BD.
define BD_FILE_REFRESH_RULE
$(BD_PROXY_DIR)/.refresh__$(bd): $(BD_SRC_DIR)/$(bd).tcl $(BD_PROXY_DIR)/.refresh | $(BD_PROXY_DIR)
	@mkdir -p $$(@D)
	@touch $$@
endef
$(foreach bd,$(BD_LIST),$(eval $(BD_FILE_REFRESH_RULE)))

# Create global refresh file as needed
$(BD_PROXY_DIR)/.refresh: | $(BD_PROXY_DIR)
	@test -f $@ || touch $@

# Recipe for creating/updating BDs
# Only create/update the subset of BDs for which a refresh is required.
$(BD_PROXY_DIR)/.refreshed: $(BD_PROXY_REFRESH_FILES) | $(PROJ_XPR) $(BD_PROXY_DIR)
	@echo "----------------------------------------------------------"
	@echo "Create/update BD ($(COMPONENT_NAME)) ..."
	@for bd in $(subst .refresh__,,$(notdir $?)); do \
		if [ -d $(BD_PROXY_DIR)/$$bd ]; then \
			rm -rf $(BD_PROXY_DIR)/$$bd.old && \
				mv $(BD_PROXY_DIR)/$$bd $(BD_PROXY_DIR)/$$bd.old; \
		fi; \
	done
	@cd $(BD_PROXY_DIR) && $(VIVADO_MANAGE_BD_CMD) -tclargs create_bd $(BUILD_OPTIONS) $(foreach bd,$(subst .refresh__,,$(notdir $?)),-bd_tcl $(BD_SRC_DIR)/$(bd).tcl)
	@resultString="\nUpdate summary:\n"; \
	for bd in $(subst .refresh__,,$(notdir $?)); do \
	resultString="$$resultString\t$$bd:"; \
		cmp -s $(BD_PROXY_DIR)/$$bd/$$bd.bd $(BD_PROXY_DIR)/$$bd.old/$$bd.bd; \
		retVal=$$?; \
		case $$retVal in \
			0) \
				resultString="$$resultString No change.\n";;\
			1) \
				cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_BD_CMD) -tclargs remove_bd $(BUILD_OPTIONS) -bd_file $(COMPONENT_OUT_PATH)/$$bd/$$bd.bd; \
				rm -rf $(COMPONENT_OUT_PATH)/$$bd; \
				mkdir -p $(COMPONENT_OUT_PATH)/$$bd; \
				cp $(BD_PROXY_DIR)/$$bd/$$bd.bd $(COMPONENT_OUT_PATH)/$$bd/$$bd.bd; \
				resultString="$$resultString BD updated.\n";; \
			2) \
				if [ -f $(COMPONENT_OUT_PATH)/$$bd/$$bd.bd ]; then \
					cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_BD_CMD) -tclargs remove_bd $(BUILD_OPTIONS) -bd_file $(COMPONENT_OUT_PATH)/$$bd/$$bd.bd; \
					rm -rf $(COMPONENT_OUT_PATH)/$$bd; \
				fi; \
				mkdir -p $(COMPONENT_OUT_PATH)/$$bd; \
				cp $(BD_PROXY_DIR)/$$bd/$$bd.bd $(COMPONENT_OUT_PATH)/$$bd/$$bd.bd; \
				resultString="$$resultString BD created.\n";; \
		esac; \
	done; \
	echo $$resultString
	@touch $@
	@echo "Done."

# BD files are generated via the bd target; downstream targets (i.e. those that
# generate simulation and synthesis output products) depend on the BD file only
# so that they only get updated when necessary, i.e. when the BD specification has
# changed.
$(BD_FILES): bd
	@for bd in $(BD_LIST); do \
		if [ ! -f $(COMPONENT_OUT_PATH)/$$bd/$$bd.bd ]; then \
			echo "----------------------------------------------------------"; \
			echo "Repairing BD ($(COMPONENT_NAME):$$bd) ..."; \
			rm -rf $(COMPONENT_OUT_PATH)/$$bd; \
			mkdir -p $(COMPONENT_OUT_PATH)/$$bd; \
			cp $(BD_PROXY_DIR)/$$bd/$$bd.bd $(COMPONENT_OUT_PATH)/$$bd/$$bd.bd; \
			echo; \
			echo "Done."; \
		fi; \
	done

# -----------------------------------------------
# BD management targets
# -----------------------------------------------
# Reset BD output products
_bd_reset: bd | $(PROJ_XPR)
	@echo "----------------------------------------------------------"
	@echo "Reset BD output products ($(COMPONENT_NAME)) ..."
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_BD_CMD) -tclargs reset $(BUILD_OPTIONS) $(foreach bdfile,$(BD_FILES),-bd_file $(bdfile))
	@echo
	@echo "Done."

# Report on BD status (version, upgrade availability, etc)
_bd_status: bd | $(PROJ_XPR)
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_BD_CMD) -tclargs status $(BUILD_OPTIONS)

# Upgrade BD IP (not supported)
_bd_upgrade:
	@echo "BD upgrade not supported."

# Compile IP
_bd_compile: _bd_sim_sources _compile_sim

# Synthesize IP
_bd_synth: $(BD_DCP_FILES) _bd_synth_sources

# Clean IP
_bd_clean: _vivado_clean_logs _bd_proj_clean _compile_clean
	@rm -rf $(COMPONENT_OUT_PATH)
	@-find $(OUTPUT_ROOT) -type d -empty -delete 2>/dev/null

.PHONY: _bd_reset _bd_status_bd_compile _bd_synth _bd_clean

# -----------------------------------------------
# Generate/manage synthesis products
# -----------------------------------------------
$(BD_DCP_FILES): _bd_dcp_files.intermediate ;
	@for dcp_file in $(BD_DCP_FILES); do \
		test -f $$dcp_file && touch $$dcp_file || false; \
	done

_bd_dcp_files.intermediate: $(BD_XCI_FILES) | $(PROJ_XPR)
	@echo "----------------------------------------------------------"
	@echo "Synthesize BD ($(COMPONENT_NAME)) ..."
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_BD_CMD) -tclargs synth $(BUILD_OPTIONS) $(foreach bdfile,$(BD_FILES),-bd_file $(bdfile))
	@echo

.INTERMEDIATE: _bd_dcp_files.intermediate

_bd_synth_sources: | $(COMPONENT_OUT_SYNTH_PATH)
	@echo "# =====================================================" > $(SYNTH_SOURCES_OBJ)
	@echo "# Source listing for $(COMPONENT_NAME)" >> $(SYNTH_SOURCES_OBJ)
	@echo "#" >> $(SYNTH_SOURCES_OBJ)
	@echo "# NOTE: This file is autogenerated. DO NOT EDIT." >> $(SYNTH_SOURCES_OBJ)
	@echo "# =====================================================" >> $(SYNTH_SOURCES_OBJ)
	@echo >> $(SYNTH_SOURCES_OBJ)
	@echo "# Xilinx BD source listing" >> $(SYNTH_SOURCES_OBJ)
	@echo "# ------------------------" >> $(SYNTH_SOURCES_OBJ)
	@rm -rf $(COMPONENT_OUT_SYNTH_PATH)/*.f
	@-for bdfile in $(abspath $(BD_FILES)); do \
		echo $$bdfile >> $(COMPONENT_OUT_SYNTH_PATH)/ip_srcs.f; \
		echo "read_bd -quiet $$bdfile" >> $(SYNTH_SOURCES_OBJ); \
	done
	@echo >> $(SYNTH_SOURCES_OBJ)

.PHONY: _bd_synth_sources

# -----------------------------------------------
# Generate/manage simulation sources
# -----------------------------------------------
__BD_SIM_SRC_FILES = $(addprefix $(COMPONENT_OUT_PATH)/,$(BD_SIM_SRC_FILES))
__BD_SIM_INC_DIRS = $(addprefix $(COMPONENT_OUT_PATH)/,$(BD_SIM_INC_DIRS))

$(__BD_SIM_SRC_FILES) $(__BD_SIM_INC_DIRS): _bd_sim_sources.intermediate ;

_bd_sim_sources.intermediate: $(BD_XCI_FILES) | $(PROJ_XPR)
	@echo "----------------------------------------------------------"
	@echo "Generate BD simulation output products ($(COMPONENT_NAME)) ..."
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_BD_CMD) -tclargs sim $(BUILD_OPTIONS) $(foreach bdfile,$(BD_FILES),-bd_file $(bdfile))
	@echo
	@echo "Done."

_bd_sim_sources: $(__BD_SIM_SRC_FILES) $(__BD_SIM_INC_DIRS)

.INTERMEDIATE: _bd_sim_sources.intermediate

# Include source files and include directories
# as compile sources for sim
SRC_FILES += $(__BD_SIM_SRC_FILES)
INC_DIRS += $(__BD_SIM_INC_DIRS)

.PHONY: _bd_sim_sources

# -----------------------------------------------
# Info targets
# -----------------------------------------------
_bd_config_info: _vivado_info
	@echo "----------------------------------------------------------"
	@echo "Manage IP configuration"
	@echo "----------------------------------------------------------"
	@echo "SRC_ROOT            : $(SRC_ROOT)"
	@echo "BD_SRC_DIR          : $(BD_SRC_DIR)"
	@echo "PROJ_XPR            : $(PROJ_XPR)"
	@echo "BD_LIST             :"
	@for bd in $(BD_LIST); do \
		echo "\t$$bd"; \
	done
	@echo "BD_FILES        :"
	@for bd_file in $(BD_FILES); do \
		echo "\t$$bd_file"; \
	done
	@echo "BD_DCP_FILES        :"
	@for dcp_file in $(BD_DCP_FILES); do \
		echo "\t$$dcp_file"; \
	done
	@echo "BD_SIM_SRC_FILES    :"
	@for src_file in $(__BD_SIM_SRC_FILES); do \
		echo "\t$$src_file"; \
	done
	@echo "BD_INC_DIRS         :"
	@for inc_dir in $(__BD_SIM_INC_DIRS); do \
		echo "\t$$inc_dir"; \
	done

_bd_info: _bd_config_info _compile_info

.PHONY: _bd_config_info _bd_info

# -----------------------------------------------
# Include compile targets
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_compile.mk
