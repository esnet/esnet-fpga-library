# -----------------------------------------------------------------------------
# Config Makefile snippet
#
#  Provides standardized configuration and configuration checking.
#
#  Expected to be included in a parent Makefile, where the following variables
#  are defined:
#
#  CFG_ROOT - path to configuration directory.
# -----------------------------------------------------------------------------
# Includes
include $(SCRIPTS_ROOT)/Makefiles/config_vivado.mk
include $(SCRIPTS_ROOT)/Makefiles/config_env.mk

# Targets
config_check: vivado_check env_check

.PHONY: config_check
