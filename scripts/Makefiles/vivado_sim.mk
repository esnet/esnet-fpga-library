# This Makefile provides generic instructions for simulating a
# a design with Xilinx Vivado Simulator.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - SCRIPTS_ROOT: path to project scripts directory
#        - RUN_DIR: path to simulation output/run directory
#        - SNAPSHOT: name of elaboration snapshot to simulate
#        - SEED: random seed value
#        - waves: waveform options (OFF/ON)
#        - PLUSARGS: list of (+arg) run-time arguments/definitions to pass to simulator
#        - SIM_OPTS: list of options to be passed to simulator

# -----------------------------------------------
# Configuration
# -----------------------------------------------
SEED ?= 0
RUN_DIR = run_$(SEED)

# -----------------------------------------------
# Import Vivado elaboration targets
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_elab.mk

# -----------------------------------------------
# Runtime arguments (+args)
# -----------------------------------------------
PLUSARGS ?=
PLUSARG_REFS = $(PLUSARGS:%=--testplusarg %)

# -----------------------------------------------
# Sim options
# -----------------------------------------------
SIM_OPTS ?=

# -----------------------------------------------
# Log files
# -----------------------------------------------
SIM_LOG = --log sim.log
SIM_CMD_LOG = sim.sh

# -----------------------------------------------
# Simulator command
# -----------------------------------------------
XSIM_BASE_CMD = xsim $(SIM_LOG) $(PLUSARG_REFS) $(SIM_OPTS) $(SNAPSHOT) -sv_seed $(SEED)

SIM_CMD_NO_WAVES = $(XSIM_BASE_CMD) -R

ALL_WAVES_TCL_FILE := $(abspath $(SCRIPTS_ROOT)/vivado/sim_waves_all.tcl)
SIM_CMD_ALL_WAVES = $(XSIM_BASE_CMD) -wdb waves.wdb -tclbatch $(ALL_WAVES_TCL_FILE)

SIM_CMD = $(if $(filter ON,$(waves)),$(SIM_CMD_ALL_WAVES),$(SIM_CMD_NO_WAVES))

# -----------------------------------------------
# Targets
# -----------------------------------------------
_sim: _elab
	@cd $(RUN_DIR) && \
	echo $(SIM_CMD) > $(SIM_CMD_LOG) && \
	$(SIM_CMD)

_clean_sim: _elab_clean
	@echo -n "Removing run directories... "
	@find . -maxdepth 1 -type d -regex "\./run_[0-9]+" -exec rm -rf {} \;
	@echo "Done."

.PHONY: _sim _clean_sim
