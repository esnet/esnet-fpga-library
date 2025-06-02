# This Makefile provides standard library configuration,
# to be used by downstream makefiles used to compile, elaborate,
# build, simulate etc.
#
# Usage: this Makefile is used by including it in a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - OUTPUT_ROOT : path to output (generated) files
#        - OUTPUT_SUBDIR : optional output subdirectory for generated files; for classifying by part, tool version, etc.
# ----------------------------------------------------
# Config
# ----------------------------------------------------
ifdef OUTPUT_SUBDIR
LIB_OUTPUT_ROOT ?= $(OUTPUT_ROOT)/$(OUTPUT_SUBDIR)
else
LIB_OUTPUT_ROOT ?= $(OUTPUT_ROOT)
endif

# ----------------------------------------------------
# Tool check
# ----------------------------------------------------
include $(CFG_ROOT)/vivado.mk

ifndef XILINX_VIVADO
$(error Vivado not configured. Expecting Vivado v$(PROJ_VIVADO_VERSION))
else
ifneq ($(notdir $(XILINX_VIVADO)), $(PROJ_VIVADO_VERSION__MAJOR))
$(error This project expects Vivado $(PROJ_VIVADO_VERSION) (found Vivado $(notdir $(XILINX_VIVADO))))
endif
endif

# ----------------------------------------------------
# Environment
# ----------------------------------------------------
# Common environment
BUILD_ID ?= $(shell date +"%s")
