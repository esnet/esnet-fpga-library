# -----------------------------------------------
# Component setup
# -----------------------------------------------
COMPONENT_ROOT := ..

include $(COMPONENT_ROOT)/config.mk

# ----------------------------------------------------
# Sources
# ----------------------------------------------------
SRC_FILES =
INC_DIRS =
SRC_LIST_FILES =

# ----------------------------------------------------
# Dependencies
# ----------------------------------------------------
SUBCOMPONENTS = \
    axi4.pkg \
    std.rtl

EXT_LIBS =

# ----------------------------------------------------
# Defines
# ----------------------------------------------------
DEFINES =

# ----------------------------------------------------
# Options
# ----------------------------------------------------
COMPILE_OPTS =

# ----------------------------------------------------
# Targets
# ----------------------------------------------------
all: compile synth

pre:     _compile_pre
compile: _compile_sim
synth:   _compile_synth
info:    _compile_info
clean:   _compile_clean

.PHONY: all pre compile synth info clean

# ----------------------------------------------------
# Import Vivado compile targets
# ----------------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_compile.mk
