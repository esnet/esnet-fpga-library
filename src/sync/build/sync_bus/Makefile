# -----------------------------------------------
# (Global) Path setup
# -----------------------------------------------
IP_ROOT := ../..

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
TOP = sync_bus_wrapper

# -----------------------------------------------
# (Local) Paths
# -----------------------------------------------
OUT_DIR=out

# -----------------------------------------------
# Regmap YAML definitions
# -----------------------------------------------
REG_BLOCK_YAML =
REG_DECODER_YAML :=

# -----------------------------------------------
# regio options
# -----------------------------------------------
REGIO_ELABORATE_OPTS :=
REGIO_GENERATE_OPTS := --recursive

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

clean: _clean_reg _clean_build
.PHONY: clean

# -----------------------------------------------
# Include Vivado definitions/targets
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_build_core.mk

# -----------------------------------------------
# Include regio targets
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/regio.mk

