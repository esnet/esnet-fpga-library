# -----------------------------------------------
# Project path setup
# -----------------------------------------------
# Set relative to LIB_ROOT (current) directory
# Note: LIB_ROOT is configured in calling (parent) Makefile
SCRIPTS_ROOT := $(abspath $(LIB_ROOT)/scripts)
REGIO_ROOT   := $(abspath $(LIB_ROOT)/tools/regio)
SVUNIT_ROOT  := $(abspath $(LIB_ROOT)/tools/svunit)
