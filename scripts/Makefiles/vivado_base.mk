# -----------------------------------------------
# Include generic compile configuration
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/compile_base.mk

# -----------------------------------------------
# Library name (lower-case)
# -----------------------------------------------
LIB_NAME_LOWER = $(shell echo $(LIB_NAME) | tr '[:upper:]' '[:lower:]')

# -----------------------------------------------
# Format component dependencies as Vivado libraries
# -----------------------------------------------
# Vivado library references in form lib_name=lib_path (e.g. component_name=component_path/lib)
COMPONENT_LIBS := $(addsuffix /lib,$(COMPONENT_REFS))

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
