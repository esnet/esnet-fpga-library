# -----------------------------------------------
# IP root Makefile snippet
#
#   - provides standard targets for IP libraries
# -----------------------------------------------
# Targets
_regression:
ifeq ($(wildcard tests/regression),)
	@echo "Skipping regression. No test suite present."
else
	@$(MAKE) -s -C tests/regression
endif

.PHONY: _regression
