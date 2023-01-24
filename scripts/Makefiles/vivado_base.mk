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
