read_verilog -sv [glob *.sv ]
read_verilog -sv [glob ../rtl/src/*.sv ]

read_xdc timing.xdc
read_xdc sync.xdc
