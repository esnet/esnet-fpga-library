set module_name xilinx_axi_reg_slice

create_ip -name axi_register_slice -vendor xilinx.com -library ip -module_name $module_name -dir . -force
