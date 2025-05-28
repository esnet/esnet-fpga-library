# ------------------------------------------------------------------
# Vivado IP configuration
#
# - list of IP cores used in project for which licenses are
#   (or may be) required
# - used for validating that the proper licenses are in place
#   ahead of launching builds
# - omitting IP here only omits that IP from being considered in the
#   pre-validation step (i.e. it does not omit the IP from the design)
#
#   Format is [Vivado IP def spec]=[IP core revision]
#   e.g. xilinx.com:ip:cmac_usplus:3.1=1
# ------------------------------------------------------------------
# IP listings can (and often must) be provided per tool version. Simultaneous
# support for multiple patch versions of the tool is supported by managing
# IP definitions files, which are searched in the following order:
# 
# 1. $(CFG_ROOT)/[active_vivado_version]/vivado_ip.mk
#     
#     (where active_vivado_version is the version currently configured in the
#      system, i.e the result of vivado -version)
#
# 2. $(CFG_ROOT)/$(PROJ_VIVADO_VERSION)/vivado_ip.mk
#
# 3. Defaults (provided in this file, below) 
#
# Note: the currently configured Vivado IP can be queried using `make vivado_ip_info`

# Provide IP defaults (only used when no version-specific config is provided)
VIVADO_IP ?= \
    xilinx.com:ip:cam:2.6=0 \
    xilinx.com:ip:cdcam:1.0=0 \
    xilinx.com:ip:vitis_net_p4:2.0=0

# ------------------------------------------------------------------
# Import targets for querying tool and IP version info
# ------------------------------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/cfg_vivado_ip_base.mk


