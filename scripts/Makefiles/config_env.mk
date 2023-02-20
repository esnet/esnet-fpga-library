# -----------------------------------------------------------------------------
# Env config Makefile snippet
#
#  Provides standardized environment config, including checks for required
#  command-line utilities.
#
#  Expected to be included in a parent Makefile, where the following variables
#  are defined:
#
#  CFG_ROOT - path to configuration directory.
# -----------------------------------------------------------------------------
# Include configuration settings
ifeq ($(wildcard $(CFG_ROOT)/env.mk),)
ENV_CMD_LINE_UTILS =
else
include $(CFG_ROOT)/env.mk
endif

env_cmd_line_utils_check:
	@for cmd_line_util in $(ENV_CMD_LINE_UTILS); do \
		(command -v $$cmd_line_util > /dev/null) || echo "ERROR: Required utility not found in path ($$cmd_line_util)"; \
	done

env_check: env_cmd_line_utils_check

.PHONY: env_cmd_line_utils_check env_check
