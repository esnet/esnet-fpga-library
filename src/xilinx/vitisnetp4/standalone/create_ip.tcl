set vitis_net_p4_ip_name $env(VITIS_NET_P4_IP_NAME)
set p4_file $env(__P4_FILE)

puts "P4 file: $p4_file"

create_project ip_proj ip_proj -part xcu280-fsvh2892-2L-e -ip -force
create_ip -name vitis_net_p4 -vendor xilinx.com -library ip -module_name $vitis_net_p4_ip_name -dir . -force
set P4_OPTS [concat [list CONFIG.P4_FILE $p4_file] [list CONFIG.OUTPUT_METADATA_FOR_DROPPED_PKTS true] [list CONFIG.PKT_RATE 300]]
set_property -dict $P4_OPTS [get_ips vitis_net_p4_0]
generate_target all [get_files $vitis_net_p4_ip_name/$vitis_net_p4_ip_name.xci]
