create_clock -name clk -period 4 [get_ports {from_controller\\.aclk to_peripheral\\.aclk}]
