create_clock -name clk -period 4 [get_ports {axi3_if_from_controller\\.aclk axi3_if_to_peripheral\\.aclk}]
