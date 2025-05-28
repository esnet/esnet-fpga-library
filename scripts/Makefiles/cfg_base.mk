# ----------------------------------------------------
# Include Vivado tool/IP config
# ----------------------------------------------------
include $(CFG_ROOT)/vivado.mk
include $(CFG_ROOT)/vivado_ip.mk

# ----------------------------------------------------
# Help
# ----------------------------------------------------
_help: __header _config_help

__header:
	@echo "ESnet FPGA library"
	@echo "========================================"

.PHONY: __header _help

# ----------------------------------------------------
# Check targets
# ----------------------------------------------------
_vivado_version_check: .vivado_version_check
_vivado_ip_check: .vivado_ip_check
_vivado_check: _vivado_version_check _vivado_ip_check

_check: _vivado_check

.PHONY: _vivado_version_check _vivado_ip_check _vivado_check _check

# ----------------------------------------------------
# Info targets
# ----------------------------------------------------
_vivado_version_info:  .vivado_version_info
_vivado_ip_info: .vivado_ip_info
_vivado_info: _vivado_version_info _vivado_ip_info

_info: _vivado_info

.PHONY: _vivado_version_info _vivado_ip_info _vivado_info _info

