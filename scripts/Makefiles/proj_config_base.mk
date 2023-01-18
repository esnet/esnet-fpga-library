# -----------------------------------------------
# Configure project path defaults
#
# - assumes PROJ_ROOT is defined by calling Makefile
# -----------------------------------------------
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

