# -----------------------------------------------
# Project path setup
# -----------------------------------------------
# Set relative to LIB_ROOT (current) directory
# Note: LIB_ROOT is configured in calling (parent) Makefile
SCRIPTS_ROOT := $(abspath $(LIB_ROOT)/scripts)
CFG_ROOT     := $(abspath $(LIB_ROOT)/cfg)
REGIO_ROOT   := $(abspath $(LIB_ROOT)/tools/regio)
SVUNIT_ROOT  := $(abspath $(LIB_ROOT)/tools/svunit)

export ONS_ROOT ?= $(abspath $(LIB_ROOT)/../open-nic-shell)
