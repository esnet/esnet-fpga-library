# -----------------------------------------------
# Path setup
# -----------------------------------------------
COMPONENT_ROOT := .

# -----------------------------------------------
# Component config
# -----------------------------------------------
include $(COMPONENT_ROOT)/config.mk

# -----------------------------------------------
# Targets
# -----------------------------------------------
all: regression

regression:
	@$(MAKE) -C tests/rs/regression
	@$(MAKE) -C tests/fec/regression
	@$(MAKE) -C tests/rs_acc/regression

.PHONY: all regression

# Import standard (root) component targets
include $(SCRIPTS_ROOT)/Makefiles/component_base.mk

