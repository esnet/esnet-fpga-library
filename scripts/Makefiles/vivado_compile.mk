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
SYNTH_CONSTRAINTS_OBJ = $(COMPONENT_OUT_SYNTH_PATH)/constraints.tcl

list_files = $(shell test -e $(1) && cat $(1) | tr '\n' ' ')

SYNTH_IP_XCI_FILES = $(sort $(foreach subcomponent_path,$(SUBCOMPONENT_PATHS),$(call list_files,$(subcomponent_path)/synth/ip_srcs.f)))
SYNTH_V_SRC_FILES  = $(sort $(abspath $(V_SRC_FILES))  $(foreach subcomponent_path,$(SUBCOMPONENT_PATHS),$(call list_files,$(subcomponent_path)/synth/v_srcs.f)))
SYNTH_V_HDR_FILES  = $(sort $(abspath $(V_HDR_FILES))  $(foreach subcomponent_path,$(SUBCOMPONENT_PATHS),$(call list_files,$(subcomponent_path)/synth/v_hdrs.f)))
SYNTH_SV_SRC_FILES = $(sort $(abspath $(SV_SRC_FILES)) $(foreach subcomponent_path,$(SUBCOMPONENT_PATHS),$(call list_files,$(subcomponent_path)/synth/sv_srcs.f)))
SYNTH_SV_HDR_FILES = $(sort $(abspath $(SV_HDR_FILES)) $(foreach subcomponent_path,$(SUBCOMPONENT_PATHS),$(call list_files,$(subcomponent_path)/synth/sv_hdrs.f)))
SYNTH_DCP_FILES    = $(foreach subcomponent_path,$(SUBCOMPONENT_PATHS),$(call list_files,$(subcomponent_path)/synth/dcp_srcs.f))

# List of package files should be unique, but not sorted, to preserve ordering of dependencies
SYNTH_SV_PKG_FILES = $(call uniq,$(foreach subcomponent_path,$(SUBCOMPONENT_PATHS),$(call list_files,$(subcomponent_path)/synth/sv_pkg_srcs.f)) $(abspath $(SV_PKG_FILES)))

SYNC_MODULE_NAMES = sync_meta sync_areset sync_bus
SYNC_CONSTRAINT_XDC_FILES = $(foreach syncmodule,$(SYNC_MODULE_NAMES),$(LIB_ROOT)/src/sync/build/$(syncmodule)/synth.xdc)

RAM_MODULE_NAMES = xilinx_ram_sdp_lutram
RAM_CONSTRAINT_XDC_FILES = $(foreach rammodule,$(RAM_MODULE_NAMES),$(LIB_ROOT)/src/xilinx/ram/build/$(rammodule)/synth.xdc)

SYNTH_FILES = \
    $(SYNTH_IP_XCI_FILES) \
    $(SYNTH_V_SRC_FILES) $(SYNTH_V_HDR_FILES) \
    $(SYNTH_SV_PKG_FILES) $(SYNTH_SV_SRC_FILES) $(SYNTH_SV_HDR_FILES) \
	$(SYNTH_DCP_FILES)

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

_compile_synth: .subcomponents_synth _synth_sources _synth_constraints

_compile_clean: .subcomponents_clean
	@[ ! -d $(OBJ_DIR) ] && [ ! -d $(COMPONENT_OUT_SYNTH_PATH) ] || (echo "Cleaning $(COMPONENT_NAME)..." && rm -rf $(OBJ_DIR) && rm -rf $(COMPONENT_OUT_SYNTH_PATH))
	@-find $(LIB_OUTPUT_ROOT) -type d -empty -delete 2>/dev/null
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

_synth_sources: $(SRCS) $(HDRS) | $(COMPONENT_OUT_SYNTH_PATH)
	@-rm -rf $(COMPONENT_OUT_SYNTH_PATH)/*.f
	@echo "# =====================================================" > $(SYNTH_SOURCES_OBJ)
	@echo "# Source listing for $(COMPONENT_NAME)" >> $(SYNTH_SOURCES_OBJ)
	@echo "#" >> $(SYNTH_SOURCES_OBJ)
	@echo "# NOTE: This file is autogenerated. DO NOT EDIT." >> $(SYNTH_SOURCES_OBJ)
	@echo "# =====================================================" >> $(SYNTH_SOURCES_OBJ)
	@echo >> $(SYNTH_SOURCES_OBJ)
	@echo "# Xilinx IP source listing" >> $(SYNTH_SOURCES_OBJ)
	@echo "# ------------------------" >> $(SYNTH_SOURCES_OBJ)
	@if [ ! -z "$(strip $(SYNTH_IP_XCI_FILES))" ]; then \
		echo "read_ip -quiet {" >> $(SYNTH_SOURCES_OBJ); \
	fi
	@-for xcifile in $(abspath $(SYNTH_IP_XCI_FILES)); do \
		echo $$xcifile >> $(COMPONENT_OUT_SYNTH_PATH)/ip_srcs.f; \
		echo "\t$$xcifile" >> $(SYNTH_SOURCES_OBJ); \
	done
	@if [ ! -z "$(strip $(SYNTH_IP_XCI_FILES))" ]; then \
		echo "}" >> $(SYNTH_SOURCES_OBJ); \
	fi
	@echo >> $(SYNTH_SOURCES_OBJ)
	@echo "# Verilog source file listing" >> $(SYNTH_SOURCES_OBJ)
	@echo "# ---------------------------" >> $(SYNTH_SOURCES_OBJ)
	@if [ ! -z "$(strip $(SYNTH_V_SRC_FILES))" ]; then \
		echo "add_file -quiet {" >> $(SYNTH_SOURCES_OBJ); \
	fi
	@-for vsrcfile in $(abspath $(SYNTH_V_SRC_FILES)); do \
		echo $$vsrcfile >> $(COMPONENT_OUT_SYNTH_PATH)/v_srcs.f; \
	    echo "\t$$vsrcfile" >> $(SYNTH_SOURCES_OBJ); \
	done
	@if [ ! -z "$(strip $(SYNTH_V_SRC_FILES))" ]; then \
		echo "}" >> $(SYNTH_SOURCES_OBJ); \
	fi
	@echo >> $(SYNTH_SOURCES_OBJ)
	@echo "# Verilog header file listing" >> $(SYNTH_SOURCES_OBJ)
	@echo "# ---------------------------" >> $(SYNTH_SOURCES_OBJ)
	@if [ ! -z "$(strip $(SYNTH_V_HDR_FILES))" ]; then \
		echo "add_file -quiet {" >> $(SYNTH_SOURCES_OBJ); \
	fi
	@-for vhdrfile in $(abspath $(SYNTH_V_HDR_FILES)); do \
		echo $$vhdrfile >> $(COMPONENT_OUT_SYNTH_PATH)/v_hdrs.f; \
		echo "\t$$vhdrfile" >> $(SYNTH_SOURCES_OBJ); \
	done
	@if [ ! -z "$(strip $(SYNTH_V_HDR_FILES))" ]; then \
		echo "}" >> $(SYNTH_SOURCES_OBJ); \
	fi
	@echo >> $(SYNTH_SOURCES_OBJ)
	@echo "# SystemVerilog package listing" >> $(SYNTH_SOURCES_OBJ)
	@echo "# -----------------------------" >> $(SYNTH_SOURCES_OBJ)
	@if [ ! -z "$(strip $(SYNTH_SV_PKG_FILES))" ]; then \
		echo "add_file -quiet {" >> $(SYNTH_SOURCES_OBJ); \
	fi
	@-for svpkgfile in $(SYNTH_SV_PKG_FILES); do \
		echo $$svpkgfile >> $(COMPONENT_OUT_SYNTH_PATH)/sv_pkg_srcs.f; \
		echo "\t$$svpkgfile" >> $(SYNTH_SOURCES_OBJ); \
	done
	@if [ ! -z "$(strip $(SYNTH_SV_PKG_FILES))" ]; then \
		echo "}" >> $(SYNTH_SOURCES_OBJ); \
	fi
	@echo >> $(SYNTH_SOURCES_OBJ)
	@echo "# SystemVerilog source file listing" >> $(SYNTH_SOURCES_OBJ)
	@echo "# ---------------------------------" >> $(SYNTH_SOURCES_OBJ)
	@if [ ! -z "$(strip $(SYNTH_SV_SRC_FILES))" ]; then \
		echo "add_file -quiet {" >> $(SYNTH_SOURCES_OBJ); \
	fi
	@-for svsrcfile in $(abspath $(SYNTH_SV_SRC_FILES)); do \
		echo $$svsrcfile >> $(COMPONENT_OUT_SYNTH_PATH)/sv_srcs.f; \
	    echo "\t$$svsrcfile" >> $(SYNTH_SOURCES_OBJ); \
	done
	@if [ ! -z "$(strip $(SYNTH_SV_SRC_FILES))" ]; then \
		echo "}" >> $(SYNTH_SOURCES_OBJ); \
	fi
	@echo >> $(SYNTH_SOURCES_OBJ)
	@echo "# SystemVerilog header file listing" >> $(SYNTH_SOURCES_OBJ)
	@echo "# ---------------------------------" >> $(SYNTH_SOURCES_OBJ)
	@if [ ! -z "$(strip $(SYNTH_SV_HDR_FILES))" ]; then \
		echo "add_file -quiet {" >> $(SYNTH_SOURCES_OBJ); \
	fi
	@-for svhdrfile in $(abspath $(SYNTH_SV_HDR_FILES)); do \
		echo $$svhdrfile >> $(COMPONENT_OUT_SYNTH_PATH)/sv_hdrs.f; \
		echo "\t$$svhdrfile" >> $(SYNTH_SOURCES_OBJ); \
	done
	@if [ ! -z "$(strip $(SYNTH_SV_HDR_FILES))" ]; then \
		echo "}" >> $(SYNTH_SOURCES_OBJ); \
	fi
	@test -e $(COMPONENT_OUT_SYNTH_PATH)/sv_hdrs.f && echo "Wrote SystemVerilog header file manifest." || true
	@echo >> $(SYNTH_SOURCES_OBJ)
	@echo "# Synthesized DCP source listing" >> $(SYNTH_SOURCES_OBJ)
	@echo "# ------------------------------" >> $(SYNTH_SOURCES_OBJ)
	@if [ ! -z "$(strip $(SYNTH_DCP_FILES))" ]; then \
		echo "read_checkpoint -quiet {" >> $(SYNTH_SOURCES_OBJ); \
	fi
	@-for dcpfile in $(abspath $(SYNTH_DCP_FILES)); do \
		echo $$dcpfile >> $(COMPONENT_OUT_SYNTH_PATH)/dcp_srcs.f; \
		echo "\t$$dcpfile" >> $(SYNTH_SOURCES_OBJ); \
	done
	@if [ ! -z "$(strip $(SYNTH_DCP_FILES))" ]; then \
		echo "}" >> $(SYNTH_SOURCES_OBJ); \
	fi
	@test -e $(COMPONENT_OUT_SYNTH_PATH)/ip_dcps.f && echo "Wrote synthesized DCP source file manifest." || true

_synth_constraints: | $(COMPONENT_OUT_SYNTH_PATH)
	@echo "# ======================================================" > $(SYNTH_CONSTRAINTS_OBJ)
	@echo "# Default timing constraints" >> $(SYNTH_CONSTRAINTS_OBJ)
	@echo "#" >> $(SYNTH_CONSTRAINTS_OBJ)
	@echo "# Includes per-reference constraints for sync (synchronizer)" >> $(SYNTH_CONSTRAINTS_OBJ)
	@echo "# and xilinx.ram (RAM) modules with clock domain crossing" >> $(SYNTH_CONSTRAINTS_OBJ)
	@echo "# (CDC) paths." >> $(SYNTH_CONSTRAINTS_OBJ)
	@echo "#" >> $(SYNTH_CONSTRAINTS_OBJ)
	@echo "# NOTE: This file is autogenerated. DO NOT EDIT." >> $(SYNTH_CONSTRAINTS_OBJ)
	@echo "# =====================================================" >> $(SYNTH_CONSTRAINTS_OBJ)
	@echo >> $(SYNTH_CONSTRAINTS_OBJ)
	@echo "# Synchronizer constraints" >> $(SYNTH_CONSTRAINTS_OBJ)
	@echo "# ------------------------" >> $(SYNTH_CONSTRAINTS_OBJ)
	@-for syncmodule in $(SYNC_MODULE_NAMES); do \
		echo "if {[lsearch [get_files -compile_order sources -used_in synthesis] *sync/rtl/src/$$syncmodule.sv] >= 0} {" >> $(SYNTH_CONSTRAINTS_OBJ); \
		echo "\tread_xdc -quiet -unmanaged -ref $$syncmodule $(abspath $(LIB_ROOT)/src/sync/build/$$syncmodule/synth.xdc)" >> $(SYNTH_CONSTRAINTS_OBJ); \
		echo "}" >> $(SYNTH_CONSTRAINTS_OBJ); \
	done
	@echo >> $(SYNTH_CONSTRAINTS_OBJ)
	@echo "# RAM constraints" >> $(SYNTH_CONSTRAINTS_OBJ)
	@echo "# ---------------" >> $(SYNTH_CONSTRAINTS_OBJ)
	@-for rammodule in $(RAM_MODULE_NAMES); do \
		echo "if {[lsearch [get_files -compile_order sources -used_in synthesis] *ram/rtl/src/$$rammodule.sv] >= 0} {" >> $(SYNTH_CONSTRAINTS_OBJ); \
		echo "\tread_xdc -quiet -unmanaged -ref $$rammodule $(abspath $(LIB_ROOT)/src/xilinx/ram/build/$$rammodule/synth.xdc)" >> $(SYNTH_CONSTRAINTS_OBJ); \
		echo "}" >> $(SYNTH_CONSTRAINTS_OBJ); \
	done
	@echo >> $(SYNTH_CONSTRAINTS_OBJ)
	@echo "# SLR crossing constraints" >> $(SYNTH_CONSTRAINTS_OBJ)
	@echo "#-------------------------" >> $(SYNTH_CONSTRAINTS_OBJ)
	@echo "if {[lsearch [get_files -compile_order sources -used_in synthesis] *bus/rtl/src/bus_pipe_slr.sv] >= 0} {" >> $(SYNTH_CONSTRAINTS_OBJ); \
	 echo "\tread_xdc -quiet -unmanaged -ref bus_pipe_slr $(abspath $(LIB_ROOT)/src/bus/build/bus_pipe_slr/synth.xdc)" >> $(SYNTH_CONSTRAINTS_OBJ); \
	 echo "}" >> $(SYNTH_CONSTRAINTS_OBJ);

.PHONY: _synth_sources _synth_constraints

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
