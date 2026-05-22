# Non-project (batch-mode) Vivado build infrastructure.
# Supports all phases: synth, link, opt, place, place_opt,
# route, route_opt, device_image.
#
# Usage: include at the end of a parent Makefile after defining:
#   TOP                   - top module name
#   BUILD_STAGES          - ordered list of phases to run (default: synth)
#
# Synthesis-phase variables:
#   OOC                   - 0 (default, full-device) or 1 (out-of-context)
#   SOURCES_TCL_USER      - user sources TCL hook(s); default: sources.tcl if present
#   CONSTRAINTS_XDC_SYNTH - synthesis XDC files (timing_ooc.xdc, etc.)
#   IP_REPO_PATHS         - IP repository paths (for BD IP resolution)
#
# Link/impl-phase variables:
#   TOP_DCP_FILE          - path to top-level DCP (shell synth output)
#   CELL_DCPS             - list of "cell:path" pairs for black_box cells
#   CONSTRAINTS_XDC_IMPL  - implementation-only XDC files
#   IMPL_HOOK_TCL_FILES   - hook TCL files (opt.pre, opt.post, place.pre, etc.)

# -----------------------------------------------
# Configure defaults
# -----------------------------------------------
OOC                   ?= 0
SOURCES_TCL_USER      ?= $(if $(wildcard $(abspath sources.tcl)),$(abspath sources.tcl),)
CONSTRAINTS_XDC_SYNTH ?=
TOP_DCP_FILE          ?=
CELL_DCPS             ?=
CONSTRAINTS_XDC_IMPL  ?=
IMPL_HOOK_TCL_FILES   ?=
IP_REPO_PATHS         ?=
BUILD_STAGES          ?= synth

# -----------------------------------------------
# Import base Vivado definitions (must precede
# eval stage-rule generation)
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_base.mk

# -----------------------------------------------
# Command
# -----------------------------------------------
VIVADO_NP_CMD = $(VIVADO_CMD_BASE) \
    -source $(VIVADO_SCRIPTS_ROOT)/build_non_proj.tcl \
    -mode batch

# -----------------------------------------------
# Build options
# -----------------------------------------------
BUILD_JOBS ?= 4

BUILD_TIMESTAMP ?= $(shell date +"%s")
BUILD_ID        ?= $(BUILD_TIMESTAMP)
BITSTREAM_USERID = $(shell printf "0x%08x" $(BUILD_ID))

# Expand "cell:path" pairs in CELL_DCPS into "-cell_dcp cell path" flags
__CELL_DCP_ARGS = $(foreach cd,$(CELL_DCPS), \
    -cell_dcp $(word 1,$(subst :, ,$(cd))) $(word 2,$(subst :, ,$(cd))))

BUILD_NP_OPTIONS = \
    -part $(PART) \
    -ooc $(OOC) \
    $(foreach tcl,$(SOURCES_TCL_AUTO),-sources_tcl $(tcl)) \
    $(foreach tcl,$(SOURCES_TCL_USER),-sources_tcl $(tcl)) \
    $(foreach tcl,$(CONSTRAINTS_TCL_AUTO),-constraints_tcl $(tcl)) \
    $(foreach xdc,$(CONSTRAINTS_XDC_SYNTH),-constraints_xdc_synth $(xdc)) \
    $(foreach repo,$(IP_REPO_PATHS),-ip_repo $(repo)) \
    -top_dcp $(TOP_DCP_FILE) \
    $(__CELL_DCP_ARGS) \
    $(foreach xdc,$(CONSTRAINTS_XDC_IMPL),-constraints_xdc $(xdc)) \
    $(foreach hook,$(IMPL_HOOK_TCL_FILES),-hook_tcl $(hook)) \
    -out_dir $(COMPONENT_OUT_PATH) \
    -jobs $(BUILD_JOBS) \
    -timestamp $(BUILD_TIMESTAMP) \
    -userid $(BITSTREAM_USERID) \
    -usr_access $(BITSTREAM_USERID)

# -----------------------------------------------
# Stage targets
#
# Each stage writes a sentinel file on success.
# Stages are chained: each depends on the previous
# sentinel.  The first stage depends on _pre_synth
# (order-only) to trigger subcomponent builds.
# -----------------------------------------------
__NP_SENTINEL_DIR  = $(COMPONENT_OUT_PATH)/.done
__NP_PREV_SENTINEL :=

define NP_STAGE_RULE
$(__NP_SENTINEL_DIR)/$(stage): \
    $(__NP_PREV_SENTINEL) \
    $(if $(strip $(__NP_PREV_SENTINEL)),,| _pre_synth)
	@echo "----------------------------------------------------------"
	@echo "Non-project build: running $(stage) for '$(TOP)' ..."
	@mkdir -p $(COMPONENT_OUT_PATH)
	@mkdir -p $(__NP_SENTINEL_DIR)
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_NP_CMD) -tclargs $(stage) $(TOP) $(BUILD_NP_OPTIONS)
	@touch $$@
	@echo
	@echo "Done."

_np_$(stage): $(__NP_SENTINEL_DIR)/$(stage)
.PHONY: _np_$(stage)
__NP_PREV_SENTINEL := $(__NP_SENTINEL_DIR)/$(stage)
endef
$(foreach stage,$(BUILD_STAGES),$(eval $(NP_STAGE_RULE)))

# -----------------------------------------------
# Synthesis library manifest (DCP path for consumers)
# -----------------------------------------------
SYNTH_DCP_FILE = $(COMPONENT_OUT_PATH)/$(TOP).synth.dcp

# -----------------------------------------------
# XSA output path (for firmware consumers)
# -----------------------------------------------
XSA_FILE = $(COMPONENT_OUT_PATH)/$(TOP).xsa

_build_np_synth_lib: | $(COMPONENT_OUT_SYNTH_PATH)
	@echo "----------------------------------------------------------"
	@echo "Compiling synthesis library '$(COMPONENT_NAME)' ..."
	@-rm -rf $(COMPONENT_OUT_SYNTH_PATH)/*.f
	@echo $(abspath $(SYNTH_DCP_FILE)) > $(COMPONENT_OUT_SYNTH_PATH)/dcp_srcs.f
	@echo "Done."

# -----------------------------------------------
# Pre-synth: trigger subcomponent builds
# -----------------------------------------------
_pre_synth: _compile_synth

.PHONY: _pre_synth

# -----------------------------------------------
# Clean
# -----------------------------------------------
_build_clean: _vivado_clean_logs
	@rm -rf $(COMPONENT_OUT_PATH) $(__NP_SENTINEL_DIR)

.PHONY: _build_clean

# -----------------------------------------------
# Info
# -----------------------------------------------
_np_info: _vivado_info _compile_info
	@echo "------------------------------------------------------"
	@echo "Non-project build configuration"
	@echo "------------------------------------------------------"
	@echo "TOP            : $(TOP)"
	@echo "OOC            : $(OOC)"
	@echo "BUILD_STAGES   : $(BUILD_STAGES)"
	@echo "TOP_DCP_FILE   : $(TOP_DCP_FILE)"
	@echo "CELL_DCPS      : $(CELL_DCPS)"

_build_info: _np_info

.PHONY: _np_info _build_info

# -----------------------------------------------
# Include compile infrastructure
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_compile.mk
