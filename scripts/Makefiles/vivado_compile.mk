# This Makefile provides generic instructions for compiling a
# a simulation library with Xilinx Vivado Simulator.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - LIB_NAME_LOWER: (lowercase) name of simulation library to create
#        - LIB_DIR: destination of simulation library
#        - COMPILE_SRC_FILES: list of source files to compile into sim library
#        - COMPILE_INC_FILES: list of header files to compile into sim library
#        - COMPILE_INC_DIRS:  list of include directories
#        - LIB_REFS: list of pre-compiled library dependencies
#        - DEFINE_REFS: list of macro definitions
#        - COMPILE_OPTS: list of options to be passed to compiler

# -----------------------------------------------
# Include generic compile configuration
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_base.mk

# -----------------------------------------------
# Output library
# -----------------------------------------------
SIM_LIB = $(addsuffix .rlx, $(LIB_DIR)/$(LIB_NAME_LOWER))

# -----------------------------------------------
# Sources
# -----------------------------------------------
# Verilog
V_SRC_FILES = $(filter %.v,$(COMPILE_SRC_FILES))
V_HDR_FILES = $(foreach incdir,$(COMPILE_INC_DIRS),$(wildcard $(incdir)/*.vh))

# SystemVerilog
SV_FILES = $(filter %.sv,$(COMPILE_SRC_FILES))
SV_PKG_FILES = $(sort $(filter %pkg.sv,$(SV_FILES)))
SV_NON_PKG_FILES = $(filter-out %pkg.sv,$(SV_FILES))
SV_HDR_FILES = $(foreach incdir,$(COMPILE_INC_DIRS),$(wildcard $(incdir)/*.svh))
# Compile packages before regular source files
SV_SRC_FILES = $(SV_PKG_FILES) $(SV_NON_PKG_FILES)

# Source dependencies
SRCS = $(SV_SRC_FILES) $(V_SRC_FILES)
HDRS = $(SV_HDR_FILES) $(V_HDR_FILES)

# -----------------------------------------------
# Component dependencies
# -----------------------------------------------
# Synthesize compiled library object dependencies in [libpath]/[libname].rlx format
COMPONENT_OBJS := $(addsuffix .rlx,$(join $(addsuffix /lib/,$(COMPONENT_PATHS)),$(COMPONENT_NAMES)))

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
V_XVLOG_LOG := --log $(LIB_DIR)/compile_v.log
SV_XVLOG_LOG := --log $(LIB_DIR)/compile_sv.log

# -----------------------------------------------
# Compiler commands
# -----------------------------------------------
XVLOG_CMD = xvlog $(INC_REFS) $(LIB_REFS) $(DEFINE_REFS) -work $(LIB_NAME_LOWER)=$(LIB_DIR)

V_COMPILE_CMD =  $(XVLOG_CMD) $(V_OPTS)  $(V_XVLOG_LOG)  $(V_SRC_FILES)
SV_COMPILE_CMD = $(XVLOG_CMD) $(SV_OPTS) $(SV_XVLOG_LOG) $(SV_SRC_FILES)

V_COMPILE = $(if $(DO_V_COMPILE),$(V_COMPILE_CMD))
SV_COMPILE = $(if $(DO_SV_COMPILE),$(SV_COMPILE_CMD))

# Log compiler commands for reference
V_COMPILE_CMD_LOG = $(if $(DO_V_COMPILE), $(shell echo $(V_COMPILE_CMD) > $(LIB_DIR)/compile_v.sh))
SV_COMPILE_CMD_LOG = $(if $(DO_SV_COMPILE), $(shell echo $(SV_COMPILE_CMD) > $(LIB_DIR)/compile_sv.sh))

# -----------------------------------------------
# TARGETS
# -----------------------------------------------
_compile: _compile_components $(SIM_LIB)

.PHONY: compile

# Compile sim library from source
$(SIM_LIB): $(SRCS) $(HDRS) $(COMPONENT_OBJS) | $(LIB_DIR)
	@echo -----------------------------------------------------
	@echo Compiling simulation library '$(LIB_NAME_LOWER)'...
	@rm -rf $(SIM_LIB)
	@echo
	$(V_COMPILE)
	@$(V_COMPILE_CMD_LOG)
	$(SV_COMPILE)
	@$(SV_COMPILE_CMD_LOG)
	@rm -f xvlog.pb
	@rm -f xvlog.log
	@echo $(LIBS) | tr ' ' '\n' > $(LIB_DIR)/sub.libs
	@echo
	@echo Done.
	@echo -----------------------------------------------------

# Compile component dependencies
_compile_components: $(COMPONENT_PATHS)

$(COMPONENT_PATHS):
	@$(MAKE) -C $@ compile

.PHONY: _compile_components $(COMPONENT_PATHS)

# Clean targets
_clean_compile: _clean_components
	@echo "Cleaning $(LIB_NAME_LOWER)..."
	@rm -rf $(LIB_DIR)
	@rm -f xvlog.pb

_clean_components:
	@for component in $(COMPONENT_PATHS); do \
		if [ -d $$component ]; then \
			$(MAKE) -C $$component clean; \
		fi \
	done

# Make library directory if it doesn't exist
$(LIB_DIR):
	@mkdir $@
