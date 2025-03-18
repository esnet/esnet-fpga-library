# Define clocks
create_clock -period 3.000 -name clk [get_ports clk]
create_clock -period 8.000 -name axil_aclk [get_ports axil_if\\.aclk]
