# This Makefile provides generic instructions for building
# (i.e. synthesizing and implementing) a design with Xilinx Vivado.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - PROJ_ROOT: path to project root directory
#        - SCRIPTS_ROOT: path to project scripts directory
#        - CFG_ROOT: path to the part configuration file(s)
#        - TOP: name of top-level module to build
#        - OUT_DIR: path to build output files
# -----------------------------------------------
# Paths
# -----------------------------------------------
VIVADO_SCRIPTS_ROOT := $(SCRIPTS_ROOT)/vivado

# Export path variables for use in Tcl scripts
export PROJ_ROOT
export LIB_ROOT

# -----------------------------------------------
# Import part configuration
# -----------------------------------------------
include $(CFG_ROOT)/part.mk

# Export part variables for use in Tcl scripts
export BOARD_REPO
export PART
export BOARD_PART

# -----------------------------------------------
# Commands
# -----------------------------------------------
VIVADO_CMD_BASE = vivado -mode batch -notrace -source $(VIVADO_SCRIPTS_ROOT)/part.tcl -source $(VIVADO_SCRIPTS_ROOT)/procs.tcl

# -----------------------------------------------
# Targets
# -----------------------------------------------
_part_cfg:
	@echo "------------------------------------------------------"
	@echo "Part configuration"
	@echo "------------------------------------------------------"
	@echo "PART:       $(PART)"
	@echo "BOARD_PART: $(BOARD_PART)"
	@echo "BOARD_REPO: $(BOARD_REPO)"

_clean_logs:
	@rm -f vivado*.jou
	@rm -f vivado*.log
	@rm -f vivado*.str
	@rm -f *.pb
	@rm -rf .Xil
