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
export OUTPUT_ROOT

# -----------------------------------------------
# Specify top-level module
# -----------------------------------------------
TOP = state_vector_sram_wrapper

# -----------------------------------------------
# (Local) Paths
# -----------------------------------------------
BUILD_OUTPUT_DIR=out

# -----------------------------------------------
# Regmap YAML definitions
# -----------------------------------------------
REG_BLOCK_YAML = 
REG_DECODER_YAML = ../../../fifo/regio/fifo_core_decoder.yaml \
                   ../../../state/regio/state_cache_decoder.yaml \
                   ../../../state/regio/state_decoder.yaml

# -----------------------------------------------
# regio options
# -----------------------------------------------
REGIO_ELABORATE_OPTS :=
REGIO_GENERATE_OPTS := --recursive

# ----------------------------------------------------
# Targets
# ----------------------------------------------------
all: opt

pre_synth: _reg_rtl
synth:     _synth
opt:       _opt
.PHONY: pre_synth synth opt

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

