# This Makefile provides generic instructions for building
# (i.e. synthesizing and implementing) a design with Xilinx Vivado.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - PROJ_ROOT: path to project root directory
#        - SCRIPTS_ROOT: path to project scripts directory
#        - TOP: name of top-level module to build
#        - PROJ_NAME: name of project
#        - PROJ_DIR: path to project
#        - OUT_DIR: path to build output files
# -----------------------------------------------
# Paths
# -----------------------------------------------
VIVADO_SCRIPTS_ROOT := $(SCRIPTS_ROOT)/vivado

# Export Make variables for use in Tcl scripts
export PROJ_ROOT
export LIB_ROOT
export TOP
export OUT_DIR

# -----------------------------------------------
# Commands
# -----------------------------------------------
VIVADO_CMD_BASE = vivado -mode batch -source $(CFG_ROOT)/part.tcl -source $(VIVADO_SCRIPTS_ROOT)/procs.tcl

# -----------------------------------------------
# Targets
# -----------------------------------------------
_clean_build:
	@rm -rf $(OUT_DIR)
	@rm -f *.jou
	@rm -f *.log
