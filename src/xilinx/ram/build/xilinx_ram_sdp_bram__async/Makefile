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
TOP = xilinx_ram_sdp_bram_wrapper

# -----------------------------------------------
# (Local) Paths
# -----------------------------------------------
BUILD_OUTPUT_DIR=out

# ----------------------------------------------------
# Targets
# ----------------------------------------------------
all: opt

pre_synth:
synth:     _synth
opt:       _opt
.PHONY: pre_synth synth opt

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

