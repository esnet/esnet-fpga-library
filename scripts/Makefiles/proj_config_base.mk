# -----------------------------------------------
# Configure project path defaults
#
# - assumes PROJ_ROOT is defined by calling Makefile
# -----------------------------------------------

# Guard: PROJ_ROOT must be set and must not resolve to the filesystem root.
ifeq ($(PROJ_ROOT),)
$(error PROJ_ROOT is not set — it must be defined before including proj_config_base.mk)
endif
ifeq ($(abspath $(PROJ_ROOT)),/)
$(error PROJ_ROOT resolves to the filesystem root — check your project configuration)
endif

SRC_ROOT ?= $(abspath $(PROJ_ROOT)/src)

# -----------------------------------------------
# Configure directory names for generated output products
# -----------------------------------------------
SIMLIB_DIRNAME := lib
REGIO_DIRNAME  := regio
IP_DIRNAME     := ip

# -----------------------------------------------
# Load config
#
#   - applies config imposed on project from enclosing
#     (parent) repository.
# -----------------------------------------------
# Check for config file at same hierarchy as $(PROJ_ROOT)
#   - config file is a Makefile snippet with name  '.<proj_dirname>.mk'
#
# e.g. if PROJ_ROOT points to ./proj-name/, the config
#      file would be found at ./proj-name/../.proj-name.mk
CONFIG_FILE := $(PROJ_ROOT)/../.$(notdir $(abspath $(PROJ_ROOT))).mk

ifneq ($(wildcard $(CONFIG_FILE)),)
# Sub-library; source configuration from parent	
include $(CONFIG_FILE)
endif

# Set config
CFG_ROOT    ?= $(CFG_ROOT__LOCAL)
OUTPUT_ROOT ?= $(OUTPUT_ROOT__LOCAL)

# Guard: OUTPUT_ROOT must be non-empty, must not be the filesystem root, and
# must resolve to a path inside PROJ_ROOT.  A misconfigured OUTPUT_ROOT would
# cause 'make clean' to rm -rf an arbitrary directory on the user's system.
ifeq ($(OUTPUT_ROOT),)
$(error OUTPUT_ROOT is empty — refusing to continue to avoid unsafe clean targets)
endif
ifeq ($(abspath $(OUTPUT_ROOT)),/)
$(error OUTPUT_ROOT resolves to the filesystem root — check your project configuration)
endif
ifneq ($(filter $(abspath $(PROJ_ROOT))/%,$(abspath $(OUTPUT_ROOT))),$(abspath $(OUTPUT_ROOT)))
$(error OUTPUT_ROOT ($(abspath $(OUTPUT_ROOT))) is not inside PROJ_ROOT ($(abspath $(PROJ_ROOT))) — refusing to continue to avoid unsafe clean targets)
endif

_proj_print_paths = @echo "--------------------------------------------"; \
               echo  "Project paths"; \
               echo "--------------------------------------------"; \
			   echo  "PROJ_ROOT:      $(abspath $(PROJ_ROOT))"; \
               echo  "LIB_ROOT:       $(LIB_ROOT)"; \
               echo  "SCRIPTS_ROOT:   $(SCRIPTS_ROOT)"; \
               echo  "CFG_ROOT:       $(CFG_ROOT)"; \
               echo  "REGIO_ROOT:     $(REGIO_ROOT)"; \
               echo  "SVUNIT_ROOT:    $(SVUNIT_ROOT)"; \
               echo  "-------------------------------------------"; \
               echo  "OUTPUT_ROOT:    $(OUTPUT_ROOT)";

# Extract Vivado major version info from $XILINX_VIVADO env variable
# - Format up to v2024.2 is /tools/Xilinx/Vivado/[version]
# - Format after v2025.1 is /tools/Xilinx/[version]/Vivado
XILINX_VIVADO__VERSION := $(firstword $(sort $(subst /, ,$(XILINX_VIVADO))))

