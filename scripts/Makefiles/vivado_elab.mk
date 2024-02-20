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
# Xilinx glbl.v
#
# - compile glbl.v file from Vivado distribution and
#   make available as top-level module to simplify
#   elaboration of designs that include Xilinx IP
# -----------------------------------------------
GLBL_V_FILE = $(XILINX_VIVADO)/data/verilog/src/glbl.v
GLBL_V_LIBRARY = __xilinx

# -----------------------------------------------
# Configuration
# -----------------------------------------------
TOP += $(GLBL_V_LIBRARY).glbl
SNAPSHOT ?= snapshot

TIMESCALE ?= 1ns/1ps

# -----------------------------------------------
# Library references
# -----------------------------------------------
COMPILE_LIB_REF = $(COMPONENT_NAME:%=-L %=$(abspath $(OBJ_DIR)))

# -----------------------------------------------
# Elaboration options
# -----------------------------------------------
ELAB_OPTS += --prj glbl.prj --timescale $(TIMESCALE)

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
_elab: _compile_sim | $(RUN_DIR)
	@cd $(RUN_DIR) && \
	echo 'verilog $(GLBL_V_LIBRARY) "$(GLBL_V_FILE)"' > glbl.prj && \
	echo $(ELAB_CMD) > $(ELAB_CMD_LOG) && \
	$(ELAB_CMD)

_elab_clean: _compile_clean
	@rm -rf $(RUN_DIR)

.PHONY: _elab _elab_clean

$(RUN_DIR):
	@mkdir -p $(RUN_DIR)

# -----------------------------------------------
# Info targets
# -----------------------------------------------
.elab_config_info:
	@echo "------------------------------------------------------"
	@echo "Elaboration configuration"
	@echo "------------------------------------------------------"
	@echo "RUN_DIR             : $(RUN_DIR)"
	@echo "SNAPSHOT            : $(SNAPSHOT)"
	@echo "ELAB_OPTS           : $(ELAB_OPTS)"
	@echo "TIMESCALE           : $(TIMESCALE)"

.elab_info: .elab_config_info .compile_info

_elab_info: .elab_info

.PHONY: .elab_config_info .elab_info _elab_info
