# ----------------------------------------------------
# IP configuration
#
# Where IP_NAME is not set explicitly by parent (calling)
# Makefile, set IP_NAME to name of IP root directory
# (with '.HDL' suffix removed, where present)
# ----------------------------------------------------
IP_NAME_RAW := $(notdir $(abspath $(IP_ROOT)))
# (Remove .HDL suffix)
IP_NAME_NORMALIZED := $(patsubst %.HDL,%,$(IP_NAME_RAW))
# (Convert to lowercase)
ifeq ($(strip $(IP_NAME)),)
	IP_NAME := $(shell echo $(IP_NAME_NORMALIZED) | tr '[:upper:]' '[:lower:]')
endif

