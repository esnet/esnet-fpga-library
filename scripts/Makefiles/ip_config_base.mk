# ----------------------------------------------------
# IP configuration
#
# Set IP_NAME to name of IP root directory
# ----------------------------------------------------
__IP_NAME := $(notdir $(abspath $(IP_ROOT)))

IP_NAME := $(shell echo $(__IP_NAME) | tr '[:upper:]' '[:lower:]')

