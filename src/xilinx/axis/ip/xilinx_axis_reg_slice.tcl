set module_name xilinx_axis_reg_slice

create_ip -name axis_register_slice -vendor xilinx.com -library ip -module_name $module_name -dir . -force
