set module_name fifo_xilinx_ila
create_ip -name ila -vendor xilinx.com -library ip -module_name $module_name -dir . -force
set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES {6}   \
    CONFIG.C_PROBE4_WIDTH  {32}  \
    CONFIG.C_PROBE5_WIDTH  {32}  \
    CONFIG.C_DATA_DEPTH    {1024}  \
    CONFIG.C_ADV_TRIGGER   {FALSE}  \
    CONFIG.C_INPUT_PIPE_STAGES {2} \
    CONFIG.ALL_PROBE_SAME_MU {true}
] [get_ips $module_name]
