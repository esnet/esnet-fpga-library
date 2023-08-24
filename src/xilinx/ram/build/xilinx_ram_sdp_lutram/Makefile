# -----------------------------------------------
# (Global) Path setup
# -----------------------------------------------
IP_ROOT := ../../..

# -----------------------------------------------
# IP config
# -----------------------------------------------
include $(IP_ROOT)/config.mk

# -----------------------------------------------
# Export parameters used in add_sources.tcl
# -----------------------------------------------
export LIB_ROOT

# -----------------------------------------------
# Specify top-level module
# -----------------------------------------------
TOP = xilinx_ram_sdp_lutram_wrapper

# -----------------------------------------------
# (Local) Paths
# -----------------------------------------------
OUT_DIR=out

# ----------------------------------------------------
# Targets
# ----------------------------------------------------
all: opt

pre_synth:
synth:     _synth
opt:       _opt
place:     _place
phys_opt:  _phys_opt
route:     _route
.PHONY: pre_synth synth opt place phys_opt route

clean: _clean_build
.PHONY: clean

# -----------------------------------------------
# Include Vivado definitions/targets
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_build_core.mk

# -----------------------------------------------
# Include regio targets
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/regio.mk

