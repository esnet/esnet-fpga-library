# This Makefile provides generic definitions for executing
# scripts in non-project mode using Vivado
# (i.e. for managing IP, synthesizing and implementing designs, etc.)
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - SCRIPTS_ROOT: path to project scripts directory
#        - CFG_ROOT: path to the part configuration file(s)
# -----------------------------------------------
# Paths
# -----------------------------------------------
VIVADO_SCRIPTS_ROOT := $(SCRIPTS_ROOT)/vivado

# -----------------------------------------------
# Part config
# -----------------------------------------------
VIVADO_PART_CONFIG = \
    -part $(PART) \
    -board_part $(BOARD_PART) \
    -board_repo $(abspath $(BOARD_REPO))

# -----------------------------------------------
# Project config
# -----------------------------------------------
VIVADO_PROJ_CONFIG = \
    -proj_name $(PROJ_NAME) \
    -proj_dir $(PROJ_DIR)

PROJ_XPR = $(PROJ_DIR)/$(PROJ_NAME).xpr

# -----------------------------------------------
# Configure source files
# -----------------------------------------------
SOURCES_TCL_AUTO = $(COMPONENT_OUT_PATH)/synth/sources.tcl
CONSTRAINTS_TCL_AUTO = $(COMPONENT_OUT_PATH)/synth/constraints.tcl

# -----------------------------------------------
# Tool options
# -----------------------------------------------
VIVADO_DEFAULT_OPTIONS = -notrace -nojournal
VIVADO_OPTIONS += $(VIVADO_DEFAULT_OPTIONS)

# -----------------------------------------------
# Commands
# -----------------------------------------------
VIVADO_CMD_BASE = vivado $(VIVADO_OPTIONS) -source $(VIVADO_SCRIPTS_ROOT)/procs.tcl

# -----------------------------------------------
# Targets
# -----------------------------------------------
# Display path configuration
_vivado_path_info:
	@echo "------------------------------------------------------"
	@echo "(Vivado) path configuration"
	@echo "------------------------------------------------------"
	@echo "CFG_ROOT            : $(CFG_ROOT)"
	@echo "VIVADO_SCRIPTS_ROOT : $(VIVADO_SCRIPTS_ROOT)"

# Display tool configuration
_vivado_tool_info:
	@echo "------------------------------------------------------"
	@echo "(Vivado) tool configuration"
	@echo "------------------------------------------------------"
	@echo "VIVADO_OPTIONS      : $(VIVADO_OPTIONS)"

# Display part configuration
_vivado_part_info:
	@echo "------------------------------------------------------"
	@echo "Part configuration"
	@echo "------------------------------------------------------"
	@echo "PART                : $(PART)"
	@echo "BOARD_PART          : $(BOARD_PART)"
	@echo "BOARD_REPO          : $(BOARD_REPO)"

# Display (consolidated) info
_vivado_info: _vivado_path_info _vivado_tool_info _vivado_part_info

.PHONY: _vivado_path_info _vivado_tool_info _vivado_part_info _vivado_info

# Remove any Vivado logs created in source directory
VIVADO_FILES_TO_CLEAN = *.jou *.log *.str *.pb
VIVADO_DIRS_TO_CLEAN = .Xil
_vivado_clean_logs:
	@for file in $(VIVADO_FILES_TO_CLEAN); do \
		rm -f $$file;\
	done
	@for dir in $(VIVADO_DIRS_TO_CLEAN); do \
		rm -rf $$dir;\
	done

.PHONY: _vivado_clean_logs
