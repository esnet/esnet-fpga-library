# ----------------------------------------------------
# Path setup
# ----------------------------------------------------
SRC_ROOT = .

include config.mk

# ----------------------------------------------------
# Targets
# ----------------------------------------------------
help: _help

.PHONY: help

compile: _compile

compile_clean: _compile_clean

.PHONY: compile compile_clean

reg: _reg

.PHONY: reg

synth: _synth

.PHONY: synth

info: _info

.PHONY: info

clean: _clean

.PHONY: clean

# ----------------------------------------------------
# Include standard library targets
# ----------------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/lib_base.mk
