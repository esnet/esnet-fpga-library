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

# Guard: LIB_OUTPUT_ROOT must be non-empty and must not resolve to the
# filesystem root.  Either condition would make _clean_all catastrophically
# destructive.  The broader OUTPUT_ROOT-inside-PROJ_ROOT check is handled
# upstream in proj_config_base.mk.
ifeq ($(LIB_OUTPUT_ROOT),)
$(error LIB_OUTPUT_ROOT is empty — check OUTPUT_ROOT and OUTPUT_SUBDIR)
endif
ifeq ($(abspath $(LIB_OUTPUT_ROOT)),/)
$(error LIB_OUTPUT_ROOT resolves to the filesystem root — check OUTPUT_ROOT and OUTPUT_SUBDIR)
endif

# Safe removal helper — mirrors __rm_rf from component_config_base.mk.
__lib_rm_rf = $(if $(strip $(1)),,$(error __lib_rm_rf called with empty path))rm -rf $(1)

# ----------------------------------------------------
# Environment
# ----------------------------------------------------
# Common environment
BUILD_ID ?= $(shell date +"%s")
