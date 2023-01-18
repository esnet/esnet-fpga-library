# This Makefile provides generic instructions for elaborating a
# a design with Xilinx Vivado Simulator.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - SCRIPTS_ROOT: path to project scripts directory
#        - RUN_DIR: path to output/run directory
#        - COMPONENT_NAME: name of pre-compiled simulation library
#        - OBJ_DIR: destination of pre-compiled simulation library
#        - TOP: name of top module(s) for design
#        - SNAPSHOT: name of snapshot to create
#        - LIB_REFS: list of pre-compiled library dependencies
#        - DEFINE_REFS: list of macro definitions
#        - ELAB_OPTS: list of options to be passed to elaboration

# -----------------------------------------------
# Import Vivado compilation targets
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_compile.mk

# -----------------------------------------------
# Configuration
# -----------------------------------------------
TOP ?=
SNAPSHOT ?= snapshot

# -----------------------------------------------
# Library references
# -----------------------------------------------
COMPILE_LIB_REF = $(COMPONENT_NAME:%=-L %=$(abspath $(OBJ_DIR)))

# -----------------------------------------------
# Elaboration options
# -----------------------------------------------
ELAB_OPTS ?=

# -----------------------------------------------
# Log files
# -----------------------------------------------
ELAB_LOG = --log elab.log
ELAB_CMD_LOG = elab.sh

# -----------------------------------------------
# Elaboration command
# -----------------------------------------------
ELAB_CMD = xelab $(TOP) $(ELAB_LOG) $(ELAB_OPTS) $(DEFINE_REFS) $(LIB_REFS) $(COMPILE_LIB_REF) -s $(SNAPSHOT)

# -----------------------------------------------
# Targets
# -----------------------------------------------
_elab: _compile | $(RUN_DIR)
	@cd $(RUN_DIR) && \
	echo $(ELAB_CMD) > $(ELAB_CMD_LOG) && \
	$(ELAB_CMD)

_clean_elab: _clean_compile
	@rm -rf $(RUN_DIR)

$(RUN_DIR):
	@mkdir $(RUN_DIR)
