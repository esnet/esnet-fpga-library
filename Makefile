# ----------------------------------------------------
# Path setup
# ----------------------------------------------------
LIB_ROOT = .

include paths.mk

# ----------------------------------------------------
# Include configuration targets
# ----------------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/config.mk

# ----------------------------------------------------
# Targets
# ----------------------------------------------------
help: _help

# Configure device properties for library
# Usage:
#   make config [PART=<part>] [BOARD_PART=<board_part>] [BOARD_REPO=<path_to_board_files>]
config: _config

.PHONY: config help

_paths:
	$(_print_paths)
