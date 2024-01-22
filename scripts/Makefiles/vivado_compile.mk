# This Makefile provides generic instructions for compiling a
# a simulation library with Xilinx Vivado Simulator.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - SIMLIB_DIRNAME: path to simulation compilation output objects
#        - COMPONENT_NAME: name of 'component' created/provided by this compilation
#        - COMPONENT_PATH: path to library for 'component' created/provided by this compilation
#        - COMPONENT_PATHS: paths to component library dependencies
#        - COMPONENT_NAMES: names of component library dependencies
#        - COMPILE_SRC_FILES: list of source files to compile into sim library
#        - COMPILE_INC_FILES: list of header files to compile into sim library
#        - COMPILE_INC_DIRS:  list of include directories
#        - LIB_REFS: list of pre-compiled library dependencies
#        - DEFINE_REFS: list of macro definitions
#        - COMPILE_OPTS: list of options to be passed to compiler

# -----------------------------------------------
# Include generic compile configuration
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/compile_base.mk

# -----------------------------------------------
# Format component dependencies as Vivado libraries
# -----------------------------------------------
# Vivado library references in form lib_name=lib_path
COMPONENT_LIBS := $(join $(addsuffix =,$(COMPONENT_NAMES)),$(COMPONENT_PATHS))

# -----------------------------------------------
# Unique list of all library dependencies
# -----------------------------------------------
LIBS = $(sort $(SUBCOMPONENT_LIBS) $(COMPONENT_LIBS) $(EXT_LIBS))

# -----------------------------------------------
# Synthesize library (-L) references
# -----------------------------------------------
LIB_REFS = $(LIBS:%=-L %)

# -----------------------------------------------
# Synthesize define (-d) references
# -----------------------------------------------
DEFINE_REFS = $(DEFINES:%=-d %)

# -----------------------------------------------
# Compiled object destination directory
# -----------------------------------------------
OBJ_DIR = $(COMPONENT_OUT_PATH)/$(SIMLIB_DIRNAME)

# -----------------------------------------------
# Output library
# -----------------------------------------------
SIM_LIB = $(addsuffix .rlx, $(OBJ_DIR)/$(COMPONENT_NAME))

# -----------------------------------------------
# Sources
# -----------------------------------------------
# Verilog
V_SRC_FILES = $(filter %.v,$(COMPILE_SRC_FILES))
V_HDR_FILES = $(foreach incdir,$(COMPILE_INC_DIRS),$(wildcard $(incdir)/*.vh))

# SystemVerilog
SV_FILES = $(filter %.sv,$(COMPILE_SRC_FILES))
# Identify header files (*.svh)
SV_HDR_FILES = $(foreach incdir,$(COMPILE_INC_DIRS),$(wildcard $(incdir)/*.svh))
# Separate source files containing package definitions (i.e. *_pkg.sv) from
# regular source files; this allows packages to be compiled first
SV_PKG_FILES = $(filter %_pkg.sv,$(SV_FILES))
SV_NON_PKG_FILES = $(filter-out %_pkg.sv,$(SV_FILES))
# Sort package files by filename (without path)
# This is somewhat arbitrary and done mostly to ensure consistency in results:

# For cases where package B requires package A, this works because A_pkg.sv is compiled first.
# For cases where package A requires package B, this doesn't work because B_pkg.sv is compiled last.
#
# Obviously more control over the compile order would be beneficial in some cases.
# However, since the general design pattern is to maintain a single package file
# per source library, this is almost always sufficient.
SV_PKG_FILES__SORTED = $(foreach pkgfile,$(sort $(join $(notdir $(addsuffix :,$(SV_PKG_FILES))),$(SV_PKG_FILES))),$(lastword $(subst :, ,$(pkgfile))))
# Compile packages before regular source files
SV_SRC_FILES = $(SV_PKG_FILES__SORTED) $(SV_NON_PKG_FILES)

# Source dependencies
SRCS = $(SV_SRC_FILES) $(V_SRC_FILES)
HDRS = $(SV_HDR_FILES) $(V_HDR_FILES)

# -----------------------------------------------
# Component dependencies
# -----------------------------------------------
# Synthesize compiled library object dependencies in [libpath]/[libname].rlx format
COMPONENT_OBJS := $(addsuffix .rlx,$(join $(addsuffix /,$(COMPONENT_PATHS)),$(COMPONENT_NAMES)))

# -----------------------------------------------
# Synthesize include (-i) references
# -----------------------------------------------
INC_REFS = $(COMPILE_INC_DIRS:%=-i %)

# -----------------------------------------------
# Compile options
# -----------------------------------------------
V_OPTS :=  $(COMPILE_OPTS)
SV_OPTS := --sv $(COMPILE_OPTS)

DO_V_COMPILE = $(strip $(V_SRC_FILES))
DO_SV_COMPILE = $(strip $(SV_SRC_FILES))

# -----------------------------------------------
# Log files
# -----------------------------------------------
V_XVLOG_LOG := --log $(OBJ_DIR)/compile_v.log
SV_XVLOG_LOG := --log $(OBJ_DIR)/compile_sv.log

# -----------------------------------------------
# Compiler commands
# -----------------------------------------------
XVLOG_CMD = xvlog $(INC_REFS) $(LIB_REFS) $(DEFINE_REFS) -work $(COMPONENT_NAME)=$(OBJ_DIR)

V_COMPILE_CMD =  $(XVLOG_CMD) $(V_OPTS)  $(V_XVLOG_LOG)  $(V_SRC_FILES)
SV_COMPILE_CMD = $(XVLOG_CMD) $(SV_OPTS) $(SV_XVLOG_LOG) $(SV_SRC_FILES)

V_COMPILE = $(if $(DO_V_COMPILE),$(V_COMPILE_CMD))
SV_COMPILE = $(if $(DO_SV_COMPILE),$(SV_COMPILE_CMD))

# Log compiler commands for reference
V_COMPILE_CMD_LOG = $(if $(DO_V_COMPILE), $(shell echo $(V_COMPILE_CMD) > $(OBJ_DIR)/compile_v.sh))
SV_COMPILE_CMD_LOG = $(if $(DO_SV_COMPILE), $(shell echo $(SV_COMPILE_CMD) > $(OBJ_DIR)/compile_sv.sh))

# -----------------------------------------------
# TARGETS
# -----------------------------------------------
_compile_sim: _compile_components $(SIM_LIB)

_compile_synth:
	@echo "Compile for synth not yet implemented (placeholder target only)."

.PHONY: _compile_sim

# Compile sim library from source
$(SIM_LIB): $(SRCS) $(HDRS) $(COMPONENT_OBJS) | $(OBJ_DIR)
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

# Compile component dependencies
_compile_components: $(COMPONENT_REFS)

$(COMPONENT_REFS):
	@$(MAKE) -s -C $(SRC_ROOT) compile COMPONENT=$@

.PHONY: _compile_components $(COMPONENT_REFS)

# Clean targets
_compile_clean_components:
	@-for component in $(COMPONENT_REFS); do \
		$(MAKE) -s -C $(SRC_ROOT) compile_clean COMPONENT=$$component; \
	done

_compile_clean: _compile_clean_components
	@[ ! -d $(OBJ_DIR) ] || (echo "Cleaning $(COMPONENT_NAME)..." && rm -rf $(OBJ_DIR))
	@-find $(OUTPUT_ROOT) -type d -empty -delete 2>/dev/null
	@rm -f xvlog.pb

.PHONY: _compile_clean_components _compile_clean

# Make library directory if it doesn't exist
$(OBJ_DIR):
	@mkdir -p $@

# Display component configuration
_compile_config_info:
	@echo "------------------------------------------------------"
	@echo "Compile configuration"
	@echo "------------------------------------------------------"
	@echo "COMPILE_OPTS        : $(COMPILE_OPTS)"
	@echo "DEFINES             :"
	@for define in $(DEFINES); do \
		echo "\t$$define"; \
	done

_compile_component_info:
	@echo "------------------------------------------------------"
	@echo "Component configuration"
	@echo "------------------------------------------------------"
	@echo "COMPONENT_NAME      : $(COMPONENT_NAME)"
	@echo "SIM_LIB             : $(SIM_LIB)"
	@echo "SRCS                :"
	@for src in $(SRCS); do \
		echo "\t$$src"; \
	done
	@echo "HDRS                :"
	@for hdr in $(HDRS); do \
		echo "\t$$hdr"; \
	done
	@echo "EXT_LIBS            :"
	@for ext_lib in $(EXT_LIBS); do \
		echo "\t$$ext_lib"; \
	done
	@echo "COMPONENTS          :"
	@for component in $(COMPONENTS); do \
		echo "\t$$component"; \
	done
	@echo "SUB_LIBS            :"
	@for sub_lib in $(sort $(COMPONENT_LIBS) $(SUBCOMPONENT_LIBS)); do \
		echo "\t$$sub_lib"; \
	done

_compile_info: _compile_config_info _compile_component_info

.PHONY: _compile_config_info _compile_component_info _compile_info
