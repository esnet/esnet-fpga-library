set lib_root $env(LIB_ROOT)

# Packages
read_verilog -sv [glob $lib_root/src/mem/rtl/src/*_pkg.sv ]

# RTL
read_verilog -sv [glob $lib_root/src/mem/rtl/src/*.sv ]

# Wrapper
read_verilog -sv mem_ram_sdp_sync_wrapper.sv
# Constraints
read_xdc -unmanaged -mode out_of_context timing_ooc.xdc
