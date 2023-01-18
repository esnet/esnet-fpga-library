# -----------------------------------------------
# Describe paths within library to provided resources,
# such as scripts/tools.
#
# The intent of this file is that it can be sourced
# by an enclosing project that makes use of the common
# scripting infrastructure provided by this library.
#
# Project-specific paths, such as the location of config
# files or output directories, are intentionally not
# included here, to avoid contention with values set in
# enclosing project.
# -----------------------------------------------
SCRIPTS_ROOT := $(abspath $(LIB_ROOT)/scripts)
REGIO_ROOT   := $(abspath $(LIB_ROOT)/tools/regio)
SVUNIT_ROOT  := $(abspath $(LIB_ROOT)/tools/svunit)
