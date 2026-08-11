# -----------------------------------------------
# Component setup
# -----------------------------------------------
COMPONENT_ROOT := ../../../..
TEST_BASE_DIR  := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

include $(COMPONENT_ROOT)/config.mk

# -----------------------------------------------
# Configuration
# -----------------------------------------------
REGRESSION ?= 0
SEED ?= 0
waves ?= OFF
SIM ?= xsim

# ----------------------------------------------------
# Dependencies
# ----------------------------------------------------
SUBCOMPONENTS = \
    xilinx.vitisnetp4.forward.ip \
    xilinx.vitisnetp4.verif \
    xilinx.vitisnetp4.example

EXT_LIBS =

# ----------------------------------------------------
# Defines
# ----------------------------------------------------
override DEFINES +=

# ----------------------------------------------------
# Run-time arguments
# ----------------------------------------------------
CLI_COMMANDS_FILE ?= $(TEST_BASE_DIR)/vitisnetp4_forward/cli_commands
override PLUSARGS += CLI_COMMANDS_FILE=$(CLI_COMMANDS_FILE)

# ----------------------------------------------------
# Options
# ----------------------------------------------------
COMPILE_OPTS =
SIM_OPTS =

ifeq ($(SIM),xsim)
ELAB_OPTS = --relax --debug typical
endif

# ----------------------------------------------------
# Targets
# ----------------------------------------------------
all: build_test sim

build_test: _build_test
sim:        _sim
info:       _sim_info
clean:      _clean_test _clean_sim

.PHONY: all build_test sim info clean

# ----------------------------------------------------
# Import SVUNIT build targets/configuration
# ----------------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/svunit.mk

# ----------------------------------------------------
# Import VitisNetP4 DPI-C elab options
# ----------------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/test_vitisnetp4.mk

# ----------------------------------------------------
# Import sim targets (backend selected by SIM variable)
# ----------------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/sim.mk
