read_verilog -sv [glob ../../rtl/src/*_pkg.sv ]
read_verilog -sv [glob ../../rtl/src/*.sv ]
read_verilog -sv [glob *.sv]

read_xdc -unmanaged timing_ooc.xdc
read_xdc -unmanaged -ref mem_ram_sdp_async synth.xdc
