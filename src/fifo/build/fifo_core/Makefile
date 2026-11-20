# -----------------------------------------------
# Component setup
# -----------------------------------------------
COMPONENT_ROOT := ../..

include $(COMPONENT_ROOT)/config.mk

# Implementation hooks run from a copied script in a checkpoint-only project.
export FIFO_CORE_CDC_LIB_ROOT := $(LIB_ROOT)

# -----------------------------------------------
# Specify top-level module
# -----------------------------------------------
TOP = fifo_core_cdc_wrapper

# ----------------------------------------------------
# Sources
#   List source files and include directories for component.
#   (see $(SCRIPTS_ROOT)/Makefiles/templates/sources.mk)
#   NOTE: along with explicitly-listed sources, all
#   source files from ./src are added automatically, and
#   .include is added as an include directory automatically.
# ----------------------------------------------------
SRC_FILES =
INC_DIRS =
SRC_LIST_FILES =

# ----------------------------------------------------
# Dependencies
#   List subcomponent and external library dependencies
#   (see $SCRIPTS_ROOT/Makefiles/templates/dependencies.mk)
# ----------------------------------------------------
SUBCOMPONENTS = \
    fifo.rtl

# ----------------------------------------------------
# Targets
# ----------------------------------------------------
all: opt validate

pre_synth: _pre_synth
synth:     _build_core_synth
opt:       _build_core_opt
place:     _build_core_place
validate:  _build_core_validate
info:      _build_core_info
clean:     _build_clean

.PHONY: pre_synth synth opt validate info clean

# ----------------------------------------------------
# Project management targets
# ----------------------------------------------------
proj       : _proj
proj_clean : _proj_clean

.PHONY: proj proj_clean

# -----------------------------------------------
# Include Vivado definitions/targets
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_build_core.mk

# Check the FIFO payload CDC scope and retained address/pointer constraints.
BUILD_OPTIONS += -hook_tcl $(abspath opt.post.tcl)
