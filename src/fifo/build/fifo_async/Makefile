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
TOP = fifo_async_wrapper

# -----------------------------------------------
# (Local) Paths
# -----------------------------------------------
# By default, the build products are generated in the output directory:
# (e.g. $(OUTPUT_ROOT)/<path_to_ip>)
# During development, it may be more convenient to produce the build outputs
# in the source tree directly (e.g. ./out)
# Set the build output directory can be changed to something other than
# the default by uncommenting the following line:
# BUILD_OUTPUT_DIR=out

# ----------------------------------------------------
# Targets
# ----------------------------------------------------
all: opt validate

reg:
	@$(MAKE) -s -C $(SRC_ROOT) reg COMPONENT=fifo.regio

pre_synth: reg
synth:     _synth
opt:       _opt
validate:  _validate
.PHONY: pre_synth synth opt validate

clean: _clean_build
.PHONY: clean

# -----------------------------------------------
# Include Vivado definitions/targets
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_build_core.mk
