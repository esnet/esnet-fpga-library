# This Makefile provides generic instructions for generating and
# managing Xilinx VitisNetP4 IP with Vivado
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - SCRIPTS_ROOT: path to project scripts directory
#        - VITISNETP4_IP_NAME: name of vitisnetp4 ip component to be created
#        - VITISNETP4_IP_DIR: location for IP source
#        - P4_FILE: path to p4 file describing vitisnetp4 component functionality
#        - P4_OPTS: (optional) dictionary of options to pass to the P4 compiler

# -----------------------------------------------
# IP config
# -----------------------------------------------
IP_LIST = $(VITISNETP4_IP_NAME)

# -----------------------------------------------
# Path setup
# -----------------------------------------------
IP_SRC_DIR = $(COMPONENT_OUT_PATH)

# -----------------------------------------------
# Source files
# -----------------------------------------------
VITISNETP4_TCL_FILE = $(IP_SRC_DIR)/$(VITISNETP4_IP_NAME).tcl

SRC_FILES = $(shell find $(XILINX_VIVADO)/data/ip/xilinx/vitis_net_p4* -name "vitis_net_p4_dpi_pkg.sv")

IP_SIM_SRC_FILES += \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_top_pkg.sv \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_pkg.sv \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_sync_fifos.sv \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_header_sequence_identifier.sv \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_header_field_extractor.sv \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_error_check_module.sv \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_extern_wrapper.sv \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_parser_engine.sv \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_deparser_engine.sv \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_action_engine.sv \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_lookup_engine.sv \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_axi4lite_interconnect.sv \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_statistics_registers.sv \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_match_action_engine.sv \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_top.sv \
    $(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME).sv

IP_SIM_INC_DIRS += \
    $(VITISNETP4_IP_NAME)/hdl/fpga_asic_macros_v1_0/hdl/include/fpga \
    $(VITISNETP4_IP_NAME)/hdl/mcfh_v1_0/hdl/mcfh_include \
    $(VITISNETP4_IP_NAME)/hdl/cue_v1_0/hdl \
    $(VITISNETP4_IP_NAME)/hdl/infrastructure_v6_4/ic_infrastructure/libs/axi \
    $(VITISNETP4_IP_NAME)/hdl/axil_mil_v2_4/axil_mil/sv/axil_mil \
    $(VITISNETP4_IP_NAME)/src/hw/simulation \
    $(VITISNETP4_IP_NAME)/src/verilog

EXT_LIBS += \
    cam_v2_6_0 \
    cam_blk_lib_v1_0_0 \
    cdcam_v1_0_0 \
    vitis_net_p4_v2_0_0 \
    unisims_ver \
    unisims_macro \
    xpm

# -----------------------------------------------
# Include base Vivado IP management Make instructions
# -----------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/vivado_manage_ip.mk

# -----------------------------------------------
# Output files
# -----------------------------------------------
VITISNETP4_XCI_FILE = $(COMPONENT_OUT_PATH)/$(VITISNETP4_IP_NAME)/$(VITISNETP4_IP_NAME).xci
VITISNETP4_DPI_DRV_FILE = $(COMPONENT_OUT_PATH)/$(VITISNETP4_IP_NAME)/vitisnetp4_drv_dpi.so
VITISNETP4_PKG_FILE = $(COMPONENT_OUT_PATH)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_pkg.sv

# -----------------------------------------------
# Options
# -----------------------------------------------
DEFAULT_P4_OPTS =
P4_OPTS += $(DEFAULT_P4_OPTS)

# -----------------------------------------------
# Targets
# -----------------------------------------------
# Custom XCI generation script; similar in intent to the standard
# _ip target provided in vivado_manage_ip.mk, but filters a timestamp
# out of the old and new XCI failures; without this filter, every
# time the XCI is created it differs from the existing XCI due to
# this timestamp.
_vitisnetp4_ip: $(VITISNETP4_TCL_FILE) | $(COMPONENT_OUT_PATH)
	@echo "----------------------------------------------------------"
	@echo "Create/update IP ($(COMPONENT_NAME)) ..."
	@mkdir -p $(COMPONENT_OUT_PATH)/.xci
	@cd $(COMPONENT_OUT_PATH)/.xci && $(VIVADO_MANAGE_IP_CMD) -tclargs create_ip $(BUILD_OPTIONS)
	@echo
	@echo "Update IP Summary:"
	@mkdir -p $(COMPONENT_OUT_PATH)/$(VITISNETP4_IP_NAME)
	@(test -e $(VITISNETP4_XCI_FILE) && cat $(VITISNETP4_XCI_FILE) | grep -v JSON_TIMESTAMP > $(COMPONENT_OUT_PATH)/.xci/old_xci) || true
	@cat $(COMPONENT_OUT_PATH)/.xci/$(VITISNETP4_IP_NAME)/$(VITISNETP4_IP_NAME).xci | grep -v JSON_TIMESTAMP > $(COMPONENT_OUT_PATH)/.xci/new_xci
	@cmp -s $(COMPONENT_OUT_PATH)/.xci/old_xci $(COMPONENT_OUT_PATH)/.xci/new_xci; \
	retVal=$$?; \
	echo -n "\t$(VITISNETP4_IP_NAME): "; \
	case $$retVal in \
		0) \
			echo "No change.";; \
		1) \
			cp $(COMPONENT_OUT_PATH)/.xci/$(VITISNETP4_IP_NAME)/$(VITISNETP4_IP_NAME).xci $(VITISNETP4_XCI_FILE); \
			echo "XCI updated.";; \
		2) \
			cp $(COMPONENT_OUT_PATH)/.xci/$(VITISNETP4_IP_NAME)/$(VITISNETP4_IP_NAME).xci $(VITISNETP4_XCI_FILE); \
			echo "XCI created.";; \
	esac
	@echo
	@echo "Done."

_vitisnetp4_dpi_drv: $(VITISNETP4_DPI_DRV_FILE)

_vitisnetp4_compile: _ip_exdes _vitisnetp4_dpi_drv _ip_compile

_vitisnetp4_synth: _ip_synth | $(COMPONENT_OUT_SYNTH_PATH)
	@rm -rf $(COMPONENT_OUT_SYNTH_PATH)/sv_pkg_srcs.f
	@echo $(abspath $(VITISNETP4_PKG_FILE)) > $(COMPONENT_OUT_SYNTH_PATH)/sv_pkg_srcs.f

_vitisnetp4_clean: _ip_clean
	@rm -f $(VITISNETP4_TCL_FILE)

.PHONY: _vitisnetp4_ip _vitisnetp4_compile _vitisnetp4_synth _vitisnetp4_clean

$(VITISNETP4_TCL_FILE): $(P4_FILE)
	@mkdir -p $(IP_SRC_DIR)
	@echo "create_ip -force -name vitis_net_p4 -vendor xilinx.com -library ip -module_name $(VITISNETP4_IP_NAME) -dir . -force" > $@
	@echo "set_property -dict [concat [list CONFIG.P4_FILE $(P4_FILE)] [list $(P4_OPTS)]] [get_ips $(VITISNETP4_IP_NAME)]" >> $@

$(VITISNETP4_DPI_DRV_FILE): $(VITISNETP4_XCI_FILE) | $(PROJ_XPR)
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs drv_dpi $(BUILD_OPTIONS)

_vitisnetp4_driver: $(VITISNETP4_XCI_FILE) | $(PROJ_XPR)
	@cd $(COMPONENT_OUT_PATH) && $(VIVADO_MANAGE_IP_CMD) -tclargs sw_driver $(BUILD_OPTIONS)
	@$(MAKE) -s -C $(COMPONENT_OUT_PATH)/$(VITISNETP4_IP_NAME)/src/sw/drivers

_vitisnetp4_info: _ip_info
	@echo "----------------------------------------------------------"
	@echo "VitisNetP4 configuration"
	@echo "----------------------------------------------------------"
	@echo "VITISNETP4_IP_NAME  : $(VITISNETP4_IP_NAME)"
	@echo "P4_FILE             : $(P4_FILE)"
	@echo "P4_OPTS             : $(P4_OPTS)"
	@echo "VITISNETP4_TCL_FILE : $(VITISNETP4_TCL_FILE)"

.PHONY: _vitisnetp4_info
