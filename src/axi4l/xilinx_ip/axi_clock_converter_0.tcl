set module_name axi_clock_converter_0

create_ip -name axi_clock_converter -vendor xilinx.com -library ip -module_name $module_name -dir . -force

set_property -dict [list \
  CONFIG.ARUSER_WIDTH {0} \
  CONFIG.AWUSER_WIDTH {0} \
  CONFIG.BUSER_WIDTH {0} \
  CONFIG.DATA_WIDTH {32} \
  CONFIG.ID_WIDTH {0} \
  CONFIG.PROTOCOL {AXI4LITE} \
  CONFIG.RUSER_WIDTH {0} \
  CONFIG.SYNCHRONIZATION_STAGES {4} \
  CONFIG.WUSER_WIDTH {0} \
] [get_ips $module_name]
