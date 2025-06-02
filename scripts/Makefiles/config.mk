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
include $(CFG_ROOT)/vivado.mk
include $(CFG_ROOT)/vivado_ip.mk
include $(SCRIPTS_ROOT)/Makefiles/config_env.mk

# Targets
config_check: .vivado_version_check .vivado_ip_check env_check

.PHONY: config_check
