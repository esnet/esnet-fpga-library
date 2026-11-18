# Generic, read-only validation of an existing Vivado checkpoint.
# Include directly, or use the inclusion from vivado_build_non_proj.mk.
ifndef __VIVADO_VALIDATE_MK
__VIVADO_VALIDATE_MK := 1

VIVADO_VALIDATION_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../vivado/validation)
VALIDATION_PYTHON ?= python3
VALIDATION_VIVADO ?= vivado
VALIDATION_NAME ?= $(TOP)
VALIDATION_CHECKPOINT ?= $(COMPONENT_OUT_PATH)/$(TOP).route_opt.dcp
VALIDATION_DIR ?= $(COMPONENT_OUT_PATH)/validation
# Additional inputs must exist and must not be newer than the checkpoint.
VALIDATION_INPUTS ?=
# Named paths have NAME=PATH syntax. Transcripts must end in a success marker
# written by run_logged.py. Log roots contain active Vivado operation/run logs.
VALIDATION_LOGS ?= $(foreach phase,$(BUILD_STAGES),$(phase)=$(COMPONENT_OUT_PATH)/$(TOP).$(phase).log)
VALIDATION_TRANSCRIPTS ?=
VALIDATION_LOG_ROOTS ?=
# Callers may extend the directories/scopes or provide explicit file lists.
VALIDATION_WAIVER_DIRS ?= $(CURDIR)/validation
VALIDATION_WAIVER_SETS ?= common $(VALIDATION_NAME)
VALIDATION_WAIVERS ?= $(foreach dir,$(VALIDATION_WAIVER_DIRS),$(foreach scope,$(VALIDATION_WAIVER_SETS),$(wildcard $(dir)/$(scope).json)))
VALIDATION_WAIVER_TCL ?= $(foreach dir,$(VALIDATION_WAIVER_DIRS),$(foreach scope,$(VALIDATION_WAIVER_SETS),$(wildcard $(dir)/$(scope).xdc)))

validate: _vivado_validate
_vivado_validate:
	@$(VALIDATION_PYTHON) $(VIVADO_VALIDATION_ROOT)/validate_build.py \
	    --checkpoint "$(VALIDATION_CHECKPOINT)" --output-dir "$(VALIDATION_DIR)" \
	    $(if $(VALIDATION_NAME),--name "$(VALIDATION_NAME)") --vivado "$(VALIDATION_VIVADO)" \
	    $(foreach input,$(VALIDATION_INPUTS),--input "$(input)") \
	    $(foreach log,$(VALIDATION_LOGS),--log "$(log)") \
	    $(foreach log,$(VALIDATION_TRANSCRIPTS),--transcript "$(log)") \
	    $(foreach root,$(VALIDATION_LOG_ROOTS),--log-root "$(root)") \
	    $(foreach waiver,$(VALIDATION_WAIVERS),--waivers "$(waiver)") \
	    $(foreach waiver,$(VALIDATION_WAIVER_TCL),--waiver-tcl "$(waiver)")
.PHONY: validate _vivado_validate
endif
