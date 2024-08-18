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
# Environment
# ----------------------------------------------------
# Common environment
BUILD_ID ?= $(shell date +"%s")
