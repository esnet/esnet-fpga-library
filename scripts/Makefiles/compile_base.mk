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
SUBCOMPONENT_PATHS := $(foreach subcomponent, $(SUBCOMPONENTS), $(OUTPUT_ROOT)/$(call get_lib_component_path_from_ref,$(subcomponent)))

# -----------------------------------------------
# Subcomponent dependencies
#
#   Collect (deduplicated) list of all sub-dependency references, i.e. the list of compilation libraries
#   required to compile each of the immediate dependencies.
# -----------------------------------------------
subcomponent_sublib_file = $(wildcard $(subcomponent_path)/sub.libs)
get_subcomponent_sublibs = $(if $(wildcard $(subcomponent_sublib_file)),$(shell cat $(subcomponent_sublib_file) | tr '\n' ' '))
SUBCOMPONENT_SUBLIBS = $(sort $(foreach suubcomponent_path,$(SUBCOMPONENT_PATHS),$(get_subcomponent_sublibs)))

# -----------------------------------------------
# Default defines
# -----------------------------------------------
DEFINES += SIMULATION

# ----------------------------------------------------
# Info target
# ----------------------------------------------------
.compile_base_info:
	@echo "------------------------------------------------------"
	@echo "Compile sources"
	@echo "------------------------------------------------------"
	@echo "SRCS                :"
	@for src in $(SRCS); do \
		echo "\t$$src"; \
	done
	@echo "HDRS                :"
	@for hdr in $(HDRS); do \
		echo "\t$$hdr"; \
	done
	@echo "------------------------------------------------------"
	@echo "Compile dependencies"
	@echo "------------------------------------------------------"
	@echo "SUBCOMPONENTS       :"
	@for subcomponent in $(SUBCOMPONENTS); do \
		echo "\t$$subcomponent"; \
	done
	@echo "SUBCOMPONENT_LIBS   :"
	@for sub_lib in $(sort $(SUBCOMPONENT_SUBLIBS) $(SUBCOMPONENT_LIBS)); do \
		echo "\t$$sub_lib"; \
	done
	@echo "EXT_LIBS            :"
	@for ext_lib in $(EXT_LIBS); do \
		echo "\t$$ext_lib"; \
	done
.PHONY: .compile_info



