# ----------------------------------------------------
# Path setup
# ----------------------------------------------------
PROJ_ROOT = .

include $(PROJ_ROOT)/config.mk

# ----------------------------------------------------
# Help
# ----------------------------------------------------
help: __header _config_help

__header:
	@echo "ESnet FPGA library"
	@echo "========================================"

.PHONY: _header help

# ----------------------------------------------------
# Configure device properties for project
# ----------------------------------------------------
# Usage:
#   make config [PART=<part>] [BOARD_PART=<board_part>] [BOARD_REPO=<path_to_board_files>]
config: _config

_paths:
	$(_proj_print_paths)

.PHONY: config _paths

# Include part configuration targets
include $(SCRIPTS_ROOT)/Makefiles/config_part.mk

# ----------------------------------------------------
# Clean project
# ----------------------------------------------------
clean:
	@echo "Removing all output products..."
	@rm -rf $(OUTPUT_ROOT)
	@echo "Done."

.PHONY: clean
