# -----------------------------------------------
# Import default component configuration
#
# Provides the following:
#   - COMPONENT_REF: reference spec for component to be compiled
#   - COMPONENT_NAME: standardized component name for component to be compiled
#   - COMPONENT_PATH: path to component source
#   - COMPONENT_BASE: component reference, not including suffix (subcomponent)
#   - SUBCOMPONENT: subcomponent reference, equivalent to suffix of component reference
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/component_base.mk

# -----------------------------------------------
# Paths
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
#        - auto-populate sources where no sources or source
#          lists are explicitly provided
#        - deduplicate
#
#    Inputs:
#      - INC_DIRS
#      - SRC_FILES
#      - SRC_LIST_FILES
#
#    Outputs:
#      - COMPILE_SRC_FILES
#      - COMPILE_INC_DIRS
# ----------------------------------------------------
# Check if source files have been explicitly specified
ifeq ($(strip $(SRC_FILES) $(SRC_LIST_FILES)),)
	# If not, import all source/header files from $(SRC_DIR) and $(INC_DIR) respectively
	COMPILE_SRC_FILES = $(wildcard $(SRC_DIR)/*.v)  $(wildcard $(SRC_DIR)/*.sv)
	COMPILE_INC_DIRS = $(sort $(INC_DIR) $(INC_DIRS))
else
	# If so, process source references provided
	_SRC_FILES = $(SRC_FILES)
	_INC_DIRS = $(INC_DIRS)
	ifneq ($(strip $(SRC_LIST_FILES)),)
		# Convert source file list to arrays of source files and include directories here
		# Note: These lists need to be created dynamically (i.e. = instead of :=)
		#       in case .f files are generated dynamically as part of the simulation process
		FILE_LIST_EXISTS = $(wildcard $(filelist))
		FILE_LIST = $(if $(FILE_LIST_EXISTS),$(shell cat $(filelist)))
		FILE_REFS = $(foreach filelist,$(SRC_LIST_FILES),$(FILE_LIST))
		_SRC_FILES += $(filter-out +incdir+%,$(FILE_REFS))
		_INC_DIRS += $(subst +incdir+,,$(filter +incdir+%,$(FILE_REFS)))
	endif
	COMPILE_SRC_FILES = $(sort $(filter %.v,$(_SRC_FILES)))
	COMPILE_SRC_FILES += $(sort $(filter %.sv,$(_SRC_FILES)))
	COMPILE_INC_DIRS = $(sort $(_INC_DIRS))
endif

# -----------------------------------------------
# Component dependencies
#
#    Process component dependency list
#        - synthesize names and paths from ref spec
#        - deduplicate
#
#    Inputs:
#        - COMPONENTS
#
#    Outputs:
#        - COMPONENT_REFS
#        - COMPONENT_NAMES
#        - COMPONENT_PATHS
# -----------------------------------------------
COMPONENTS ?=


# Normalize references - Convert to lowercase, remove extraneous . separators
__COMPONENT_REFS_UNSAFE = $(foreach component, $(COMPONENTS), $(call normalize_component_ref,$(component)))

# Filter out self-references
COMPONENT_REFS = $(filter-out $(COMPONENT_REF), $(__COMPONENT_REFS_UNSAFE))

# Synthesize component names
COMPONENT_NAMES := $(foreach component, $(COMPONENT_REFS), $(call get_component_name_from_ref,$(call get_ref_without_lib,$(component))))

# Synthesize component paths
COMPONENT_PATHS := $(foreach component, $(COMPONENT_REFS), $(OUTPUT_ROOT)/$(call get_lib_component_path_from_ref,$(component))/$(SIMLIB_DIRNAME))

# -----------------------------------------------
# Subcomponent dependencies
#
# 	Collect (deduplicated) list of all subcomponent dependency references, i.e. the list of compilation libraries
# 	required to compile each of the immediate dependencies.
# -----------------------------------------------
subcomponent_lib_file = $(wildcard $(component_path)/sub.libs)
get_subcomponent_libs = $(if $(wildcard $(subcomponent_lib_file)),$(shell cat $(subcomponent_lib_file) | tr '\n' ' '))
SUBCOMPONENT_LIBS = $(sort $(foreach component_path,$(COMPONENT_PATHS),$(get_subcomponent_libs)))

# -----------------------------------------------
# Default defines
# -----------------------------------------------
DEFINES += SIMULATION
