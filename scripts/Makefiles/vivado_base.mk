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
# Import part configuration
# -----------------------------------------------
include $(CFG_ROOT)/part.mk

# Export part variables for use in Tcl scripts
export BOARD_REPO
export PART
export BOARD_PART

# -----------------------------------------------
# Options
# -----------------------------------------------
VIVADO_DEFAULT_OPTIONS = -mode batch -notrace -nojournal

VIVADO_OPTIONS += $(VIVADO_DEFAULT_OPTIONS)

VIVADO_LOG_DIR  ?= $(CURDIR)
VIVADO_LOG_NAME ?= vivado.log

# -----------------------------------------------
# Commands
# -----------------------------------------------
VIVADO_CMD_BASE_NO_LOG = vivado $(VIVADO_OPTIONS) -source $(VIVADO_SCRIPTS_ROOT)/part.tcl -source $(VIVADO_SCRIPTS_ROOT)/procs.tcl
VIVADO_CMD_BASE = $(VIVADO_CMD_BASE_NO_LOG) -log $(VIVADO_LOG_DIR)/$(VIVADO_LOG_NAME)

# -----------------------------------------------
# Targets
# -----------------------------------------------
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
