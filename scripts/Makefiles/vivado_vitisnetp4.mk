# This Makefile provides generic instructions for generating and
# managing Xilinx VitisNetP4 IP with Vivado
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here after defining
#        the following input 'arguments':
#        - SCRIPTS_ROOT: path to project scripts directory
#        - VITISNETP4_IP_NAME: name of vitisnetp4 ip component to be created
#        - VITISNETP4_IP_DIR: location for IP source
#        - IP_OUT_DIR: location for IP output products
#        - P4_FILE: path to p4 file describing vitisnetp4 component functionality
#        - P4_OPTS: (optional) dictionary of options to pass to the P4 compiler

# -----------------------------------------------
# Path setup
# -----------------------------------------------
VITISNETP4_IP_DIR ?= $(IP_OUT_DIR)
IP_SRC_DIR = $(VITISNETP4_IP_DIR)

# -----------------------------------------------
# IP config
# -----------------------------------------------
IP_LIST = $(VITISNETP4_IP_NAME)

# -----------------------------------------------
# Source files
# -----------------------------------------------
VITISNETP4_TCL_FILE = $(abspath $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME).tcl)

VITISNETP4_SRC_FILES = \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_top_pkg.sv \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_pkg.sv \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_sync_fifos.sv \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_header_sequence_identifier.sv \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_header_field_extractor.sv \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_error_check_module.sv \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_extern_wrapper.sv \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_parser_engine.sv \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_deparser_engine.sv \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_action_engine.sv \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_lookup_engine.sv \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_axi4lite_interconnect.sv \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_statistics_registers.sv \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_match_action_engine.sv \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME)_top.sv \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog/$(VITISNETP4_IP_NAME).sv

VITISNETP4_INC_DIRS = \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/hdl/fpga_asic_macros_v1_0/hdl/include/fpga \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/hdl/mcfh_v1_0/hdl/mcfh_include \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/hdl/cue_v1_0/hdl \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/hdl/infrastructure_v6_4/ic_infrastructure/libs/axi \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/hdl/axil_mil_v2_4/axil_mil/sv/axil_mil \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/hw/simulation \
    $(VITISNETP4_IP_DIR)/$(VITISNETP4_IP_NAME)/src/verilog

SRC_FILES += $(VITISNETP4_SRC_FILES)

INC_DIRS += $(VITISNETP4_INC_DIRS)

COMPONENTS += \
    vitisnetp4.dpi

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
VITISNETP4_XCI_DIR = $(abspath $(IP_OUT_DIR)/$(VITISNETP4_IP_NAME))
VITISNETP4_XCI_FILE = $(VITISNETP4_XCI_DIR)/$(VITISNETP4_IP_NAME).xci
VITISNETP4_DPI_DRV_FILE = $(VITISNETP4_XCI_DIR)/vitisnetp4_drv_dpi.so

# -----------------------------------------------
# Options
# -----------------------------------------------
DEFAULT_P4_OPTS =
P4_OPTS += $(DEFAULT_P4_OPTS)

# -----------------------------------------------
# Targets
# -----------------------------------------------
_vitisnetp4_ip: _ip

_vitisnetp4_dpi_drv: $(VITISNETP4_DPI_DRV_FILE)

_vitisnetp4_compile: _ip_exdes _vitisnetp4_dpi_drv _ip_compile

_vitisnetp4_synth: _ip_synth

_vitisnetp4_clean: _ip_clean
	@rm -f $(VITISNETP4_TCL_FILE)

.PHONY: _vitisnetp4_ip _vitisnetp4_compile _vitisnetp4_synth _vitisnetp4_clean

$(VITISNETP4_TCL_FILE): $(P4_FILE) | $(VITISNETP4_IP_DIR)
	@echo "create_ip -force -name vitis_net_p4 -vendor xilinx.com -library ip -module_name $(VITISNETP4_IP_NAME) -dir . -force" > $@
	@echo "set_property -dict [concat [list CONFIG.P4_FILE $(P4_FILE)] [list $(P4_OPTS)]] [get_ips $(VITISNETP4_IP_NAME)]" >> $@

$(VITISNETP4_DPI_DRV_FILE): $(VITISNETP4_XCI_FILE)
	@cd $(IP_OUT_DIR) && $(VIVADO_MANAGE_IP_CMD) -tclargs drv_dpi $<

$(VITISNETP4_SRC_FILES) $(VITISNETP4_INC_DIRS): $(VITISNETP4_XCI_FILE)
	@cd $(IP_OUT_DIR) && $(VIVADO_MANAGE_IP_CMD) -tclargs generate $<

_vitisnetp4_info: _ip_info
	@echo "=============================================================================="
	@echo "VitisNetP4 configuration"
	@echo "=============================================================================="
	@echo "SCRIPTS_ROOT        : $(SCRIPTS_ROOT)"
	@echo "VITISNETP4_IP_NAME  : $(VITISNETP4_IP_NAME)"
	@echo "VITISNETP4_IP_DIR   : $(VITISNETP4_IP_DIR)"
	@echo "P4_FILE             : $(P4_FILE)"
	@echo "P4_OPTS             : $(P4_OPTS)"
	@echo "VITISNETP4_TCL_FILE : $(VITISNETP4_TCL_FILE)"

.PHONY: _vitisnetp4_info
