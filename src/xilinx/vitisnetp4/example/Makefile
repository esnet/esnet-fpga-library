# -----------------------------------------------
# Component setup
# -----------------------------------------------
COMPONENT_ROOT := ../..

include $(COMPONENT_ROOT)/config.mk

# ----------------------------------------------------
# VitisNet IP config
# ----------------------------------------------------
VITISNETP4_IP_NAME = vitisnetp4_default

#  Reference Xilinx default example (implements null pipeline)
P4_FILE = $(shell find $(XILINX_VIVADO)/data/ip/xilinx/vitis_net_p4* -name "default.p4")

INC_DIRS += $(COMPONENT_OUT_PATH)/$(VITISNETP4_IP_NAME)_ex/imports

# ----------------------------------------------------
# Dependencies
#   List subcomponent and external library dependencies
#   (see $SCRIPTS_ROOT/Makefiles/templates/dependencies.mk)
# ----------------------------------------------------
SUBCOMPONENTS =
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

# ----------------------------------------------------
# Compile Targets
# ----------------------------------------------------

all: compile

ifeq ($(P4_FILE),)
$(error No P4 file specified)
else
ip:      _vitisnetp4_ip
endif
ip_exdes: _ip_exdes
compile: ip_exdes _vitisnetp4_compile
synth:   _vitisnetp4_synth
driver:  _vitisnetp4_driver
info:    _vitisnetp4_info
status:  _ip_status
upgrade: _ip_upgrade
clean:   _vitisnetp4_clean

.PHONY: all ip compile synth info status upgrade clean

# ----------------------------------------------------
# IP project management targets
#
#   These targets are used for managing IP, i.e. creating
#   new IP, or modifying existing IP.
# ----------------------------------------------------
proj:       _ip_proj
proj_clean: _ip_proj_clean

.PHONY: proj proj_clean

# ----------------------------------------------------
# Import Vivado IP management targets
# ----------------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_vitisnetp4.mk
