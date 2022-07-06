# -----------------------------------------------
# Project path setup
# -----------------------------------------------
# Local paths
SCRIPTS_ROOT__LOCAL := $(abspath $(LIB_ROOT)/scripts)
REGIO_ROOT__LOCAL   := $(abspath $(LIB_ROOT)/tools/regio)
SVUNIT_ROOT__LOCAL  := $(abspath $(LIB_ROOT)/tools/svunit)
CFG_ROOT__LOCAL     := $(abspath $(LIB_ROOT)/cfg)

# Desired path configuration is inferred from context:

# 1. If PROJ_ROOT is configured, this Makefile is likely being
#    invoked by a 'parent' project to resolve paths to tools and
#    resources provided by the library.
ifneq ($(wildcard $(PROJ_ROOT)),)
SCRIPTS_ROOT := $(SCRIPTS_ROOT__LOCAL)
REGIO_ROOT   := $(REGIO_ROOT__LOCAL)
SVUNIT_ROOT  := $(SVUNIT_ROOT__LOCAL)
else
# Otherwise, assume that we are invoking this from within the library itself.

# 2. If the library is a subcomponent of a 'parent' project, assume that we
#    want to inherit the configuration details (device, etc.) from that project.
ifneq ($(wildcard $(LIB_ROOT)/../paths.mk),)
PROJ_ROOT = $(abspath $(LIB_ROOT)/..)
include $(PROJ_ROOT)/paths.mk
else

# 3. For standalone development, the configuration is sourced locally.
CFG_ROOT ?= $(CFG_ROOT__LOCAL)

# When invoking from within the library, we always want internal paths
# (to tools, etc) to resolve locally.
SCRIPTS_ROOT := $(SCRIPTS_ROOT__LOCAL)
REGIO_ROOT   := $(REGIO_ROOT__LOCAL)
SVUNIT_ROOT  := $(SVUNIT_ROOT__LOCAL)
endif
endif

_print_paths = @echo "--------------------------------------------"; \
               echo  "Paths"; \
               echo "--------------------------------------------"; \
               echo  "LIB_ROOT:     $(abspath $(LIB_ROOT))"; \
               echo  "SCRIPTS_ROOT: $(SCRIPTS_ROOT)"; \
               echo  "CFG_ROOT:     $(CFG_ROOT)"; \
               echo  "REGIO_ROOT:   $(REGIO_ROOT)"; \
               echo  "SVUNIT_ROOT:  $(SVUNIT_ROOT)"
