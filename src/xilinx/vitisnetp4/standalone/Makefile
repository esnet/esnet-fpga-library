# Config
VITIS_NET_P4_IP_NAME = vitis_net_p4_0
P4_FILE = pipeline.p4

# Determine Vivado and VitisNetP4 versions from $XILINX_VIVADO env variable
ifeq ($(notdir $(XILINX_VIVADO)),2022.1)
VIVADO_VERSION = 2022.1
VITIS_NET_P4_FILES = $(VITIS_NET_P4_V1_1_FILES)
VITIS_NET_P4_LIBS = -L vitis_net_p4_v1_1_0 -L cam_v2_3_0
else
ifeq ($(notdir $(XILINX_VIVADO)),2022.2)
VIVADO_VERSION = 2022.2
VITIS_NET_P4_FILES = $(VITIS_NET_P4_V1_2_FILES)
VITIS_NET_P4_LIBS = -L vitis_net_p4_v1_2_0 -L cam_v2_4_0
else
$(error Vivado version not valid.)
endif
endif

# Export 'global' variables to reference in Tcl scripts
export VITIS_NET_P4_IP_NAME
export __P4_FILE = $(abspath $(P4_FILE))

# Source list (VitisNetP4 v1.1)
VITIS_NET_P4_V1_1_FILES = \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME)_top_pkg.sv \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME)_pkg.sv \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME)_sync_fifos.sv \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME)_header_sequence_identifier.sv \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME)_header_field_extractor.sv \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME)_error_check_module.sv \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME)_parser_engine.sv \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME)_deparser_engine.sv \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME)_action_engine.sv \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME)_lookup_engine.sv \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME)_axi4lite_interconnect.sv \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME)_statistics_registers.sv \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME)_match_action_engine.sv \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME)_top.sv \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME).sv

# Source list (VitisNetP4 v1.2)
VITIS_NET_P4_V1_2_FILES = \
              $(VITIS_NET_P4_IP_NAME)/src/hw/simulation/vitis_net_p4_dpi_pkg.sv \
              $(VITIS_NET_P4_V1_1_FILES) \
              $(VITIS_NET_P4_IP_NAME)/src/verilog/$(VITIS_NET_P4_IP_NAME)_extern_wrapper.sv

# Targets

all: sim

ip: $(VITIS_NET_P4_IP_NAME)/$(VITIS_NET_P4_IP_NAME).xci

compile: xsim.dir/work/work.rlx

elab: xsim.dir/snapshot/xsimk

sim: elab
	@xsim snapshot -wdb waves.wdb -t sim.tcl

.PHONY: all ip compile elab sim clean

$(VITIS_NET_P4_IP_NAME)/$(VITIS_NET_P4_IP_NAME).xci: pipeline.p4 create_ip.tcl
	@vivado -mode batch -source create_ip.tcl

xsim.dir/work/work.rlx : xsim.dir/vitisnetp4/vitisnetp4.rlx test.sv
	@xvlog --sv -L vitisnetp4 test.sv $(XILINX_VIVADO)/data/verilog/src/glbl.v

xsim.dir/vitisnetp4/vitisnetp4.rlx : ip
	@xvlog --sv -i $(VITIS_NET_P4_IP_NAME)/src/hw/include -work vitisnetp4 $(VITIS_NET_P4_FILES)

xsim.dir/snapshot/xsimk: compile
	@xelab test glbl -debug typical -i $(VITIS_NET_P4_IP_NAME)/src/hw/include -L vitisnetp4 $(VITIS_NET_P4_LIBS) -L xpm -timescale 1ns/1ps -s snapshot

clean:
	@rm -rf xsim.dir
	@rm -rf xvlog*
	@rm -rf xelab*
	@rm -rf xsim*
	@rm -rf vivado*
	@rm -rf ip_proj
	@rm -rf ip_user_files
	@rm -rf waves.wdb
	@rm -rf .Xil/
	@rm -rf $(VITIS_NET_P4_IP_NAME)

.PHONY: clean
