# -----------------------------------------------
# Configure paths
# -----------------------------------------------
# Specify standard directory structure
INC_DIR ?= include
SRC_DIR ?= src

# ----------------------------------------------------
# Sources
#
#    Process sources specified:
#        - extract source file/include directory references
#          from source lists
#        - auto-populate sources from SRC_DIR (e.g. ./src) and
#          INC_DIR (e.g. ./include)
#        - deduplicate
#
#    Inputs:
#      - INC_DIRS
#      - SRC_FILES
#      - SRC_LIST_FILES
#
#    Outputs:
#      - INCLUDES
#      - SV_PKG_FILES, SV_SRC_FILES, SV_HDR_FILES
#      - V_SRC_FILES, V_HDR_FILES
# ----------------------------------------------------
# Import all source/header files from $(SRC_DIR) and $(INC_DIR) respectively
__SRC_FILES = $(SRC_FILES) $(sort $(wildcard $(SRC_DIR)/*.v)) $(sort $(wildcard $(SRC_DIR)/*.sv))
__INC_DIRS = $(sort $(INC_DIR) $(INC_DIRS))
# Import file lists
ifneq ($(strip $(SRC_LIST_FILES)),)
	# Convert source file list to arrays of source files and include directories here
	# Note: These lists need to be created dynamically (i.e. = instead of :=)
	#       in case .f files are generated dynamically as part of the simulation process
	FILE_LIST_EXISTS = $(wildcard $(filelist))
	FILE_LIST = $(if $(FILE_LIST_EXISTS),$(shell cat $(filelist)))
	FILE_REFS = $(foreach filelist,$(SRC_LIST_FILES),$(FILE_LIST))
	__FILE_LIST_SRC_FILES += $(filter-out +incdir+%,$(FILE_REFS))
	__FILE_LIST_INC_DIRS += $(subst +incdir+,,$(filter +incdir+%,$(FILE_REFS)))
endif
# Synthesize (unsorted, non-unique) list of all Verilog/SystemVerilog source files
__SRC_FILES = $(abspath $(SRC_FILES) $(__FILE_LIST_SRC_FILES) $(wildcard $(SRC_DIR)/*.v) $(wildcard $(SRC_DIR)/*.sv))
# Synthesize list of include directories
INCLUDES = $(sort $(abspath $(INC_DIR) $(INC_DIRS) $(__FILE_LIST_INC_DIRS)))

# Synthesize list of Verilog source files
V_SRC_FILES = $(sort $(filter %.v,$(__SRC_FILES)))
V_HDR_FILES = $(sort $(foreach incdir,$(__INC_DIRS),$(wildcard $(incdir)/*.vh)))
# Synthesize list of SystemVerilog files
__SV_FILES = $(filter %.sv,$(__SRC_FILES))
# Identify header files (*.svh)
SV_HDR_FILES = $(sort $(foreach incdir,$(__INC_DIRS),$(wildcard $(incdir)/*.svh)))
# Separate source files containing package definitions (i.e. *_pkg.sv) from
# regular source files; this allows packages to be compiled first
__SV_PKG_FILES = $(filter %_pkg.sv,$(__SV_FILES))
SV_SRC_FILES = $(sort $(filter-out %_pkg.sv,$(__SV_FILES)))
# Synthesize unique list of package files, but maintain order
# Order rules:
#   - first include packages listed in SRC_FILES
#   - next, include packages listed in file lists (e.g. SRC_LIST_FILES)
#   - finally, include packages added by wildcard match in SRC_DIR (in alphabetical order)
# These ordering rules provide some control over compile order, where for example,
# package A and package B are present, and package A depends on package B. Without
# ordering rules, this would result in a compile error when package B is compiled
# before package A. This compile error could be avoided e.g. by explicitly listing
# package B and package A (in that order) in SRC_FILES.
SV_PKG_FILES = $(call uniq,$(__SV_PKG_FILES))

# -----------------------------------------------
# Subcomponent dependencies
#
#    Process subcomponent dependency list
#        - synthesize names and paths from ref spec
#        - deduplicate
#
#    Inputs:
#        - SUBCOMPONENTS
#          - specified using dot/@ notation
#            (see $(SCRIPTS_ROOT)/Makefiles/dependencies.mk)
#
#    Outputs:
#        - COMPONENT_DEP_REFS
#        - COMPONENT_DEP_NAMES
#        - COMPONENT_DEP_PATHS
# -----------------------------------------------
SUBCOMPONENTS ?=

# Normalize references - Convert to lowercase, remove extraneous . separators
__SUBCOMPONENT_REFS_UNSAFE = $(foreach subcomponent, $(SUBCOMPONENTS), $(call normalize_component_ref,$(subcomponent)))

# Filter out self-references
SUBCOMPONENT_REFS = $(filter-out $(COMPONENT_REF), $(__SUBCOMPONENT_REFS_UNSAFE))

# Synthesize component dependency names
SUBCOMPONENT_NAMES := $(foreach subcomponent, $(SUBCOMPONENT_REFS), $(call get_component_name_from_ref,$(call get_ref_without_lib,$(subcomponent))))

# Synthesize component dependency paths
SUBCOMPONENT_PATHS := $(foreach subcomponent, $(SUBCOMPONENT_REFS), $(call get_lib_component_out_path_from_ref,$(subcomponent),$(LIB_OUTPUT_ROOT)))

# Format subcomponent dependencies as library specifications, in name=path format
SUBCOMPONENT_LIBS := $(join $(addsuffix =,$(SUBCOMPONENT_NAMES)),$(addsuffix /$(SIMLIB_DIRNAME),$(SUBCOMPONENT_PATHS)))

# Collect (deduplicated) list of all sub-dependency references, i.e. the list of compilation libraries
# required to compile each of the immediate dependencies.
subcomponent_sublib_file = $(wildcard $(subcomponent_path)/$(SIMLIB_DIRNAME)/sub.libs)
get_subcomponent_sublibs = $(if $(wildcard $(subcomponent_sublib_file)),$(shell cat $(subcomponent_sublib_file) | tr '\n' ' '))
SUBCOMPONENT_SUBLIBS = $(sort $(foreach subcomponent_path,$(SUBCOMPONENT_PATHS),$(get_subcomponent_sublibs)))

# Perform recursive operations on subcomponents
__COMPILE_OPS = compile synth clean
define SUBCOMPONENT_OP_RULE
.subcomponents_$(op):
	@-for subcomponent in $(SUBCOMPONENT_REFS); do \
		set -e && $(MAKE) -s -C $(SRC_ROOT) $(op) COMPONENT=$$$$subcomponent $(COMMON_ENV) $(LIB_ENV) $(USER_ENV); \
	done
endef
$(foreach op,$(__COMPILE_OPS),$(eval $(SUBCOMPONENT_OP_RULE)))

.PHONY: $(addprefix .subcomponents_,$(__COMPILE_OPS))

# ----------------------------------------------------
# Library dependencies
#
#   Collect unique list of all dependencies in library
#   format, including libraries corresponding to subcomponents
#   as well as external library references.
# ----------------------------------------------------
LIBS = $(sort $(SUBCOMPONENT_SUBLIBS) $(SUBCOMPONENT_LIBS) $(EXT_LIBS))

# ----------------------------------------------------
# Info target
# ----------------------------------------------------
.compile_base_info:
	@echo "------------------------------------------------------"
	@echo "Compile sources"
	@echo "------------------------------------------------------"
	@echo "SV_PKG_FILES       :"
	@for svpkgfile in $(SV_PKG_FILES); do \
		echo "\t$$svpkgfile"; \
	done
	@echo "SV_SRC_FILES       :"
	@for svsrcfile in $(SV_SRC_FILES); do \
		echo "\t$$svsrcfile"; \
	done
	@echo "SV_HDR_FILES       :"
	@for svhdrfile in $(SV_HDR_FILES); do \
		echo "\t$$svhdrfile"; \
	done
	@echo "V_SRC_FILES        :"
	@for vsrcfile in $(V_SRC_FILES); do \
		echo "\t$$vsrcfile"; \
	done
	@echo "V_HDR_FILES        :"
	@for vhdrfile in $(V_HDR_FILES); do \
		echo "\t$$vhdrfile"; \
	done
	@echo "------------------------------------------------------"
	@echo "Compile dependencies"
	@echo "------------------------------------------------------"
	@echo "SUBCOMPONENTS      :"
	@for subcomponent in $(SUBCOMPONENT_REFS); do \
		echo "\t$$subcomponent"; \
	done
	@echo "SUBCOMPONENT_LIBS  :"
	@for subcomponentlib in $(sort $(SUBCOMPONENT_LIBS) $(SUBCOMPONENT_SUBLIBS)); do \
		echo "\t$$subcomponentlib"; \
	done
	@echo "EXT_LIBS           :"
	@for ext_lib in $(EXT_LIBS); do \
		echo "\t$$ext_lib"; \
	done

.PHONY: .compile_info



