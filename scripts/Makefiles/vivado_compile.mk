# This Makefile provides generic instructions for compiling a
# a simulation library with Xilinx Vivado Simulator.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - SIMLIB_DIRNAME: path to simulation compilation output objects
#        - COMPONENT_NAME: name of 'component' created/provided by this compilation
#        - COMPONENT_PATH: path to library for 'component' created/provided by this compilation
#        - COMPONENT_OUT_PATH: path to output directory for component
#        - SUBCOMPONENT_REFS: references to subcomponent dependencies
#        - SUBCOMPONENT_PATHS: paths to subcomponent dependencies
#        - SUBCOMPONENT_NAMES: names of subcomponent dependencies
#        - SV_PKG_FILES: list of package source files to compile
#        - SV_SRC_FILES, V_SRC_FILES: list of source files to compile
#        - SV_HDR_FILES, V_HDR_FILES: list of header files to compile
#        - LIBS: list of pre-compiled library dependencies
#        - DEFINES: list of macro definitions
#        - COMPILE_OPTS: list of options to be passed to compiler

# -----------------------------------------------
# Include generic compile configuration
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/compile_base.mk

# -----------------------------------------------
# Synthesize library (-L) references
# -----------------------------------------------
LIB_REFS =$(LIBS:%=-L %)

# -----------------------------------------------
# Synthesize define (-d) references
# -----------------------------------------------
DEFINE_REFS =$(DEFINES:%=-d %)

# -----------------------------------------------
# Compiled object destination directory
# -----------------------------------------------
OBJ_DIR = $(COMPONENT_OUT_PATH)/$(SIMLIB_DIRNAME)

# -----------------------------------------------
# Simulation output library
# -----------------------------------------------
SIM_LIB = $(addsuffix .rlx, $(OBJ_DIR)/$(COMPONENT_NAME))

# -----------------------------------------------
# Synthesis outputs
# -----------------------------------------------
SYNTH_SOURCES_OBJ = $(COMPONENT_OUT_SYNTH_PATH)/sources.tcl

list_files = $(shell test -e $(1) && cat $(1) | tr '\n' ' ')

SYNTH_IP_XCI_FILES = $(sort $(foreach subcomponent_path,$(SUBCOMPONENT_PATHS),$(call list_files,$(subcomponent_path)/synth/ip_srcs.f)))
SYNTH_V_SRC_FILES  = $(sort $(abspath $(V_SRC_FILES))  $(foreach subcomponent_path,$(SUBCOMPONENT_PATHS),$(call list_files,$(subcomponent_path)/synth/v_srcs.f)))
SYNTH_V_HDR_FILES  = $(sort $(abspath $(V_HDR_FILES))  $(foreach subcomponent_path,$(SUBCOMPONENT_PATHS),$(call list_files,$(subcomponent_path)/synth/v_hdrs.f)))
SYNTH_SV_PKG_FILES = $(sort $(abspath $(SV_PKG_FILES)) $(foreach subcomponent_path,$(SUBCOMPONENT_PATHS),$(call list_files,$(subcomponent_path)/synth/sv_pkg_srcs.f)))
SYNTH_SV_SRC_FILES = $(sort $(abspath $(SV_SRC_FILES)) $(foreach subcomponent_path,$(SUBCOMPONENT_PATHS),$(call list_files,$(subcomponent_path)/synth/sv_srcs.f)))
SYNTH_SV_HDR_FILES = $(sort $(abspath $(SV_HDR_FILES)) $(foreach subcomponent_path,$(SUBCOMPONENT_PATHS),$(call list_files,$(subcomponent_path)/synth/sv_hdrs.f)))

SYNC_MODULE_NAMES = sync_meta sync_areset sync_bus
SYNC_CONSTRAINT_XDC_FILES = $(foreach syncmodule,$(SYNC_MODULES),$(LIB_ROOT)/src/sync/build/$(syncmodule)/synth.xdc)
SYNTH_CONSTRAINTS_OBJ = $(COMPONENT_OUT_SYNTH_PATH)/constraints.tcl

# -----------------------------------------------
# Sources
# -----------------------------------------------
SRCS = $(SV_PKG_FILES) $(SV_SRC_FILES) $(V_SRC_FILES)
HDRS = $(SV_HDR_FILES) $(V_HDR_FILES)

# -----------------------------------------------
# Component dependencies
# -----------------------------------------------
# Synthesize compiled library object dependencies in [libpath]/[libname].rlx format
SUBCOMPONENT_OBJS := $(addsuffix .rlx,$(join $(addsuffix /$(SIMLIB_DIRNAME)/,$(SUBCOMPONENT_PATHS)),$(SUBCOMPONENT_NAMES)))
SUBCOMPONENT_SYNTH_OBJS := $(addsuffix /synth/sources.tcl,$(SUBCOMPONENT_PATHS))

# -----------------------------------------------
# Synthesize include (-i) references
# -----------------------------------------------
INC_REFS =$(INCLUDES:%=-i %)

# -----------------------------------------------
# Compile options
# -----------------------------------------------
V_OPTS :=  $(strip $(COMPILE_OPTS))
SV_OPTS := --sv $(strip $(COMPILE_OPTS))

DO_V_COMPILE = $(strip $(V_SRC_FILES))
DO_SV_COMPILE = $(strip $(SV_PKG_FILES) $(SV_SRC_FILES))

# -----------------------------------------------
# Log files
# -----------------------------------------------
V_XVLOG_LOG := --log $(OBJ_DIR)/compile_v.log
SV_XVLOG_LOG := --log $(OBJ_DIR)/compile_sv.log

# -----------------------------------------------
# Compiler commands
# -----------------------------------------------
XVLOG_CMD = xvlog $(INC_REFS) $(LIB_REFS) $(DEFINE_REFS) -work $(COMPONENT_NAME)=$(OBJ_DIR)

V_COMPILE_CMD  = $(XVLOG_CMD) $(V_OPTS) $(V_XVLOG_LOG) $(V_SRC_FILES)
SV_COMPILE_CMD = $(XVLOG_CMD) $(SV_OPTS) $(SV_XVLOG_LOG) $(SV_PKG_FILES) $(SV_SRC_FILES)

V_COMPILE = $(if $(DO_V_COMPILE),$(strip $(V_COMPILE_CMD)))
SV_COMPILE = $(if $(DO_SV_COMPILE),$(strip $(SV_COMPILE_CMD)))

# Log compiler commands for reference
V_COMPILE_CMD_LOG = $(if $(DO_V_COMPILE), $(shell echo $(V_COMPILE_CMD) > $(OBJ_DIR)/compile_v.sh))
SV_COMPILE_CMD_LOG = $(if $(DO_SV_COMPILE), $(shell echo $(SV_COMPILE_CMD) > $(OBJ_DIR)/compile_sv.sh))

# -----------------------------------------------
# TARGETS
# -----------------------------------------------
_compile_sim: .subcomponents_compile $(SIM_LIB)

_compile_synth: .subcomponents_synth $(SYNTH_SOURCES_OBJ) $(SYNTH_CONSTRAINTS_OBJ)

_compile_clean: .subcomponents_clean
	@[ ! -d $(OBJ_DIR) ] && [ ! -d $(COMPONENT_OUT_SYNTH_PATH) ] || (echo "Cleaning $(COMPONENT_NAME)..." && rm -rf $(OBJ_DIR) && rm -rf $(COMPONENT_OUT_SYNTH_PATH))
	@-find $(OUTPUT_ROOT) -type d -empty -delete 2>/dev/null
	@rm -f xvlog.pb

.PHONY: _compile_sim _compile_synth _compile_clean

# Make output directories as necessary
$(OBJ_DIR):
	@mkdir -p $@

$(COMPONENT_OUT_SYNTH_PATH):
	@mkdir -p $@

# Compile sim library from source
$(SIM_LIB): $(SRCS) $(HDRS) $(SUBCOMPONENT_OBJS) | $(OBJ_DIR)
	@echo "----------------------------------------------------------"
	@echo "Compiling simulation library '$(COMPONENT_NAME)' ..."
	@echo
	@rm -rf $(SIM_LIB)
	$(V_COMPILE)
	@$(V_COMPILE_CMD_LOG)
	$(SV_COMPILE)
	@$(SV_COMPILE_CMD_LOG)
	@rm -f xvlog.pb
	@rm -f xvlog.log
	@echo $(LIBS) | tr ' ' '\n' > $(OBJ_DIR)/sub.libs
	@echo
	@echo "Done."

$(SYNTH_SOURCES_OBJ): $(SRCS) $(HDRS) $(SUBCOMPONENT_SYNTH_OBJS) | $(COMPONENT_OUT_SYNTH_PATH)
	@echo "----------------------------------------------------------"
	@echo "Compiling synthesis library '$(COMPONENT_NAME)' ..."
	@echo
	@-rm -rf $(COMPONENT_OUT_SYNTH_PATH)/*.f
	@echo "# =====================================================" > $@
	@echo "# Source listing for $(COMPONENT_NAME)" >> $@
	@echo "#" >> $@
	@echo "# NOTE: This file is autogenerated. DO NOT EDIT." >> $@
	@echo "# =====================================================" >> $@
	@echo >> $@
	@echo "# Xilinx IP source listing" >> $@
	@echo "# ------------------------" >> $@
	@-for xcifile in $(abspath $(SYNTH_IP_XCI_FILES)); do \
		echo $$xcifile >> $(COMPONENT_OUT_SYNTH_PATH)/ip_srcs.f; \
		echo "read_ip -quiet $$xcifile" >> $@; \
	done
	@test -e $(COMPONENT_OUT_SYNTH_PATH)/ip_srcs.f && echo "Wrote Xilinx IP source file manifest." || true
	@echo >> $@
	@echo "# Verilog source file listing" >> $@
	@echo "# ---------------------------" >> $@
	@-for vsrcfile in $(abspath $(SYNTH_V_SRC_FILES)); do \
		echo $$vsrcfile >> $(COMPONENT_OUT_SYNTH_PATH)/v_srcs.f; \
		echo "read_verilog -quiet $$vsrcfile" >> $@; \
	done
	@test -e $(COMPONENT_OUT_SYNTH_PATH)/v_srcs.f && echo "Wrote Verilog source file manifest." || true
	@echo >> $@
	@echo "# Verilog header file listing" >> $@
	@echo "# ---------------------------" >> $@
	@-for vhdrfile in $(abspath $(SYNTH_V_HDR_FILES)); do \
		echo $$vhdrfile >> $(COMPONENT_OUT_SYNTH_PATH)/v_hdrs.f; \
		echo "read_verilog -quiet $$vhdrfile" >> $@; \
	done
	@test -e $(COMPONENT_OUT_SYNTH_PATH)/v_hdrs.f && echo "Wrote Verilog header file manifest." || true
	@echo >> $@
	@echo "# SystemVerilog package listing" >> $@
	@echo "# -----------------------------" >> $@
	@-for svpkgsrcfile in $(SYNTH_SV_PKG_FILES); do \
		echo $$svpkgsrcfile >> $(COMPONENT_OUT_SYNTH_PATH)/sv_pkg_srcs.f; \
		echo "read_verilog -sv -quiet $$svpkgsrcfile" >> $@; \
	done
	@test -e $(COMPONENT_OUT_SYNTH_PATH)/sv_pkg_srcs.f && echo "Wrote SystemVerilog package source file manifest." || true
	@echo >> $@
	@echo "# SystemVerilog source file listing" >> $@
	@echo "# ---------------------------------" >> $@
	@-for svsrcfile in $(abspath $(SYNTH_SV_SRC_FILES)); do \
		echo $$svsrcfile >> $(COMPONENT_OUT_SYNTH_PATH)/sv_srcs.f; \
		echo "read_verilog -sv -quiet $$svsrcfile" >> $@; \
	done
	@test -e $(COMPONENT_OUT_SYNTH_PATH)/sv_srcs.f && echo "Wrote SystemVerilog source file manifest." || true
	@echo >> $@
	@echo "# SystemVerilog header file listing" >> $@
	@echo "# ---------------------------------" >> $@
	@-for svhdrfile in $(abspath $(SYNTH_SV_HDR_FILES)); do \
		echo $$svhdrfile >> $(COMPONENT_OUT_SYNTH_PATH)/sv_hdrs.f; \
		echo "read_verilog -sv -quiet $$svhdrfile" >> $@; \
	done
	@test -e $(COMPONENT_OUT_SYNTH_PATH)/sv_hdrs.f && echo "Wrote SystemVerilog header file manifest." || true
	@echo
	@echo "Done."

$(SYNTH_CONSTRAINTS_OBJ): $(SYNC_CONSTRAINT_XDC_FILES) | $(COMPONENT_OUT_SYNTH_PATH)
	@-rm -rf $@
	@echo "# ======================================================" > $@
	@echo "# Default synchronizer library (sync) timing constraints" >> $@
	@echo "#" >> $@
	@echo "# NOTE: This file is autogenerated. DO NOT EDIT." >> $@
	@echo "# =====================================================" >> $@
	@-for syncmodule in $(SYNC_MODULE_NAMES); do \
		echo "read_xdc -quiet -unmanaged -ref $$syncmodule $(abspath $(LIB_ROOT)/src/sync/build/$$syncmodule/synth.xdc)" >> $@; \
	done

# -----------------------------------------------
# Info targets
# -----------------------------------------------
.compile_config_info:
	@echo "------------------------------------------------------"
	@echo "Compile configuration"
	@echo "------------------------------------------------------"
	@echo "SIM_LIB             : $(SIM_LIB)"
	@echo "COMPILE_OPTS        : $(COMPILE_OPTS)"
	@echo "DEFINES             :"
	@for define in $(DEFINES); do \
		echo "\t$$define"; \
	done

.compile_info: .component_info .compile_config_info .compile_base_info

_compile_info: .compile_info

.PHONY: .compile_config_info .compile_info _compile_info
