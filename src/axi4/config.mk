# -----------------------------------------------
# Path setup
# -----------------------------------------------
SRC_ROOT := $(abspath $(COMPONENT_ROOT)/..)

include $(SRC_ROOT)/config.mk

# -----------------------------------------------
# Import default component config
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/component_config_base.mk
