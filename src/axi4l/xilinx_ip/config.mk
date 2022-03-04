# -----------------------------------------------
# Path setup
# -----------------------------------------------
# Set relative to IP directory
# Note: IP_ROOT is configured in calling (parent) Makefile
LIB_ROOT := $(IP_ROOT)/../../..

# All other project paths can be derived
include $(LIB_ROOT)/paths.mk

# -----------------------------------------------
# Custom IP config
# -----------------------------------------------
# IP library name - if unset, defaults to IP_ROOT directory name (with ".HDL" suffix stripped, when present)
IP_NAME =

# -----------------------------------------------
# Import base IP config
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/ip_base.mk
