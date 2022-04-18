read_verilog -sv [glob $env(LIB_ROOT)/src/sync/rtl/src/*.sv ]

# Constraints
read_xdc -unmanaged -mode out_of_context $env(LIB_ROOT)/src/sync/build/sync.xdc
