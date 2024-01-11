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
#
#   NOTE: By default, IP output products are being generated at
#         the path represented by $(COMPONENT_OUT_PATH). This
#         path can be queried using 'make info',
#         and $(COMPONENT_OUT_PATH) can be used to reference these
#         files for compilation.
# ----------------------------------------------------
IP_LIST = \
    fifo_xilinx_ila

SRC_FILES = \
    $(COMPONENT_OUT_PATH)/fifo_xilinx_ila/sim/fifo_xilinx_ila.v
INC_DIRS =
SRC_LIST_FILES =

# ----------------------------------------------------
# Dependencies
#   List IP component and external library dependencies
#   (see $SCRIPTS_ROOT/Makefiles/dependencies.mk)
# ----------------------------------------------------
COMPONENTS =
EXT_LIBS =

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

ip: _ip

compile: _ip_compile

synth: _ip_synth

clean: _ip_clean

.PHONY: all ip compile synth clean

# ----------------------------------------------------
# Info targets
# ----------------------------------------------------
info: _ip_info

.PHONY: info

# ----------------------------------------------------
# IP management targets
#
#   These targets are used for managing IP, i.e. creating
#   new IP, or modifying or upgrading existing IP.
# ----------------------------------------------------
ip_proj: _ip_proj

ip_upgrade: _ip_upgrade

ip_status: _ip_status

ip_proj_clean: _ip_proj_clean

.PHONY: ip_proj ip_upgrade ip_status ip_proj_clean

# ----------------------------------------------------
# Import Vivado IP management targets
# ----------------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_manage_ip.mk
