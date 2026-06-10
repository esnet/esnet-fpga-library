# -----------------------------------------------
# Component setup
# -----------------------------------------------
COMPONENT_ROOT := ../..

include $(COMPONENT_ROOT)/config.mk

# ----------------------------------------------------
# Sources
#   List source files and include directories for component.
#   (see $(SCRIPTS_ROOT)/Makefiles/templates/sources.mk)
#   NOTE: along with explicitly-listed sources, all
#   source files from ./src are added automatically, and
#   .include is added as an include directory automatically.
# ----------------------------------------------------
# WORKAROUND_DPI_PKG_BUG {
#    vitis_net_p4_dpi_pkg has an indexing bug in XilVitisNetP4DPIresetState() task where
#    CtxPtrIdx is assigned (=) rather than accumulated (+=) after the counter loop, causing
#    register resets to target wrong (null) ctxPtr slots and hang.  Patch the upstream file
#    at build time and compile the patched copy instead.
#
# SRC_FILES = $(shell find $(XILINX_VIVADO)/data/ip/xilinx/vitis_net_p4* -name "vitis_net_p4_dpi_pkg.sv")
UPSTREAM_DPI_PKG := $(shell find $(XILINX_VIVADO)/data/ip/xilinx/vitis_net_p4* -name "vitis_net_p4_dpi_pkg.sv")
PATCHED_DPI_PKG  := $(COMPONENT_OUT_PATH)/vitis_net_p4_dpi_pkg.sv
SRC_FILES = $(PATCHED_DPI_PKG)
# }
INC_DIRS =
SRC_LIST_FILES =

# ----------------------------------------------------
# Dependencies
#   List subcomponent and external library dependencies
#   (see $SCRIPTS_ROOT/Makefiles/templates/dependencies.mk)
# ----------------------------------------------------
SUBCOMPONENTS =
EXT_LIBS =

# ----------------------------------------------------
# Defines
#   List macro definitions.
# ----------------------------------------------------
DEFINES =

# ----------------------------------------------------
# Options
# ----------------------------------------------------
COMPILE_OPTS =

# ----------------------------------------------------
# Targets
# ----------------------------------------------------
all: compile synth

pre:     $(PATCHED_DPI_PKG) _compile_pre
compile: _compile_sim
synth:   _compile_synth
info:    _compile_info
clean:   _compile_clean _clean_patched_dpi_pkg

$(PATCHED_DPI_PKG): $(UPSTREAM_DPI_PKG) | $(COMPONENT_OUT_PATH)
	sed 's/CtxPtrIdx = i;/CtxPtrIdx += i;/g' $< > $@

$(COMPONENT_OUT_PATH):
	@mkdir -p $@

_clean_patched_dpi_pkg:
	@rm -f $(PATCHED_DPI_PKG)

.PHONY: all pre compile synth info clean _clean_patched_dpi_pkg

# ----------------------------------------------------
# Import Vivado compile targets
# ----------------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_compile.mk
