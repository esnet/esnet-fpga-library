# -----------------------------------------------
# Component root Makefile snippet
#
#   - provides standard targets for component library
# -----------------------------------------------
# Targets
_regression:
ifeq ($(wildcard tests/regression),)
	@echo "Skipping regression. No test suite present."
else
	@$(MAKE) -s -C tests/regression
endif

.PHONY: _regression
