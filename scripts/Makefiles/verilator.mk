# This Makefile provides generic instructions for simulating a
# a design with Verilator.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - SCRIPTS_ROOT: path to project scripts directory
#        - RUN_DIR: path to simulation output/run directory
#        - SEED: random seed value
#        - waves: waveform options (OFF/ON)
#        - PLUSARGS: list of (+arg) run-time arguments/definitions to pass to simulator
#        - SIM_OPTS: list of options to be passed to simulator

# -----------------------------------------------
# Configuration
# -----------------------------------------------
SEED ?= 0
RUN_DIR = run_$(SEED)
TOP = testrunner
TIMESCALE ?= 1ns/1ps

# -----------------------------------------------
# Include generic compile configuration
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/compile_base.mk

# -----------------------------------------------
# Synthesize include (-I) references
# -----------------------------------------------
INC_REFS =$(INC_DIRS__ALL:%=-I%)

# -----------------------------------------------
# Synthesize define (-D) references
# -----------------------------------------------
DEFINE_REFS =$(DEFINES__ALL:%=-D%)

# -----------------------------------------------
# Synthesize source file references
# -----------------------------------------------
SRCS = $(SV_PKG_FILES__ALL) $(SV_SRC_FILES__ALL) $(V_SRC_FILES__ALL)

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
VERILATE_BASE_CMD = verilator -Mdir $(RUN_DIR) --binary --timing $(if $(filter ON,$(waves)),--trace) --timescale-override $(TIMESCALE) --top $(TOP) -j 0
EXECUTE_BASE_CMD = $(PLUSARG_REFS) +verilator+seed+$(SEED)

# -----------------------------------------------
# Targets
# -----------------------------------------------
_verilate: .pre
	$(VERILATE_BASE_CMD) $(INC_REFS) $(SRCS) $(DEFINE_REFS) $(SIM_OPTS)

_sim: _verilate
	@cd $(RUN_DIR) && \
	$(SIM_BASE_CMD) ./V$(TOP)

_clean_sim:
	@echo -n "Removing run directories... "
	@find . -maxdepth 1 -type d -regex "\./run_[0-9]+" -exec rm -rf {} \;
	@echo "Done."

.PHONY: _verilate _sim _clean_sim

# -----------------------------------------------
# Info targets
# -----------------------------------------------
.verilate_info:
	@echo "------------------------------------------------------"
	@echo "(Verilator) simulation configuration"
	@echo "------------------------------------------------------"
	@echo "SIM_OPTS            : $(SIM_OPTS)"
	@echo "PLUSARGS            : $(PLUSARGS)"
	@echo "SEED                : $(SEED)"
	@echo "SRCS                : $(SRCS)"
	@echo "INC_DIRS            : $(INC_DIRS__ALL)"

_sim_info: .verilate_info

.PHONY: .verilate_info _sim_info
