read_verilog -sv [glob $env(LIB_ROOT)/src/sync/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $env(LIB_ROOT)/src/sync/rtl/src/*.sv ]
read_verilog -sv [glob *.sv ]

# Constraints
read_xdc -unmanaged timing_ooc.xdc
source ../constraints.tcl
