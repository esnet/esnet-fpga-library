# This Makefile provides generic instructions for building a
# a unit test environement using SVUnit.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - REGRESSION: switch allowing selection of single-test or regression build

# ----------------------------------------------------
# Configuration
# ----------------------------------------------------
SVUNIT_DIR := $(COMPONENT_OUT_PATH)/svunit
SVUNIT_TOP_MODULE = testrunner

# ----------------------------------------------------
# SVUnit test filter (pass as sim plusarg)
# ----------------------------------------------------
SVUNIT_FILTER ?= *

PLUSARGS += SVUNIT_FILTER=$(SVUNIT_FILTER)

# ----------------------------------------------------
# Sources
# ----------------------------------------------------
SVUNIT_FILE_LIST := $(SVUNIT_DIR)/.svunit.f

# ----------------------------------------------------
# Commands
# ----------------------------------------------------
SVUNIT_ENV_SETUP := export SVUNIT_INSTALL=$(SVUNIT_ROOT); PATH=$(SVUNIT_ROOT)/bin:$$PATH

SVUNIT_BUILD_CMD := buildSVUnit -o $(SVUNIT_DIR)

SVUNIT_VIVADO_WORKAROUND_CMD := $(abspath $(SCRIPTS_ROOT))/svunit/svunit_vivado.sh $(SVUNIT_DIR)

SVUNIT_CMD := $(SVUNIT_ENV_SETUP); $(SVUNIT_BUILD_CMD); $(SVUNIT_VIVADO_WORKAROUND_CMD)


# ----------------------------------------------------
# Compile config
# ----------------------------------------------------
SRC_LIST_FILES += $(SVUNIT_FILE_LIST)

# ----------------------------------------------------
# Elaboration config
# ----------------------------------------------------
TOP = $(COMPONENT_NAME).$(SVUNIT_TOP_MODULE)

# ----------------------------------------------------
# Targets
# ----------------------------------------------------
_build_test: | $(SVUNIT_DIR)
ifeq ($(REGRESSION), 1)
	@cd .. && $(SVUNIT_CMD)
else
	@$(SVUNIT_CMD)
endif

_clean_test:
	@rm -rf $(SVUNIT_DIR)

$(SVUNIT_DIR):
	@mkdir -p $(SVUNIT_DIR)
