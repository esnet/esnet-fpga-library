read_verilog -sv [glob $env(LIB_ROOT)/src/std/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $env(LIB_ROOT)/src/sync/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $env(LIB_ROOT)/src/xilinx/ram/rtl/src/*_pkg.sv]
read_verilog -sv [glob $env(LIB_ROOT)/src/mem/rtl/src/*_pkg.sv ]

read_verilog -sv [glob $env(LIB_ROOT)/src/xilinx/ram/rtl/src/*.sv]
read_verilog -sv [glob $env(LIB_ROOT)/src/sync/rtl/src/*.sv ]
read_verilog -sv [glob $env(LIB_ROOT)/src/mem/rtl/src/*.sv ]
read_verilog -sv [glob *.sv]

read_xdc -unmanaged timing_ooc.xdc
source $env(LIB_ROOT)/src/xilinx/ram/build/constraints.tcl
source $env(LIB_ROOT)/src/sync/build/constraints.tcl
