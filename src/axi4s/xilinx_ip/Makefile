# -----------------------------------------------
# Path setup
# -----------------------------------------------
IP_ROOT := ..

# -----------------------------------------------
# IP config
# -----------------------------------------------
include $(IP_ROOT)/config.mk

# ----------------------------------------------------
# Sources
#   List source files and include directories for component.
#   (see $(SCRIPTS_ROOT)/Makefiles/sources.mk)
#   Note: if no sources are explicitly listed, all
#   source files from ./src are added automatically,
#   with include directory ./include
# ----------------------------------------------------
IP_LIST = \
    axis_register_slice \
    axis_data_fifo \
    ila_axi4s

SRC_FILES =
INC_DIRS =
SRC_LIST_FILES = \
    axis_data_fifo/sources.f \
    ila_axi4s/sources.f

# ----------------------------------------------------
# Dependencies
#   List IP component and external library dependencies
#   (see $SCRIPTS_ROOT/Makefiles/dependencies.mk)
# ----------------------------------------------------
COMPONENTS =
EXT_LIBS = axis_infrastructure_v1_1_0 \
           axis_data_fifo_v2_0_4 \
           axis_register_slice_v1_1_25 \
           fifo_generator_v13_2_5 \
           xpm

# ----------------------------------------------------
# Defines
#   List macro definitions.
# ----------------------------------------------------
DEFINES =

# ----------------------------------------------------
# Options
# ----------------------------------------------------
COMPILE_OPTS=
ELAB_OPTS=--debug typical
SIM_OPTS=

# ----------------------------------------------------
# Compile Targets
# ----------------------------------------------------
all: compile

compile: _ip _compile

synth: _ip_synth

clean: _clean_compile _ip_proj_clean

.PHONY: all compile synth clean

# ----------------------------------------------------
# Import Vivado compile targets
# ----------------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_compile.mk

# ----------------------------------------------------
# Import Vivado IP management targets
# ----------------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_manage_ip.mk
