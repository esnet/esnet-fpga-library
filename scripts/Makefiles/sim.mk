# This Makefile snippet selects the simulation backend based on the SIM variable
# and includes the appropriate backend Makefile.
#
# Usage: replace the ifeq ($(SIM),verilator) ... endif block in test_base.mk
#        with a single line:
#
#           include $(SCRIPTS_ROOT)/Makefiles/sim.mk
#
# SIM defaults to xsim.  Set SIM=verilator on the command line to use Verilator.
#
# For verilator, _sim depends on _build_test so that the SVUnit .svunit.f file
# list is generated before verilator attempts to expand the source list.

SIM ?= xsim

ifeq ($(SIM),verilator)
_sim: _build_test
include $(SCRIPTS_ROOT)/Makefiles/verilator.mk
else
include $(SCRIPTS_ROOT)/Makefiles/vivado_sim.mk
endif
