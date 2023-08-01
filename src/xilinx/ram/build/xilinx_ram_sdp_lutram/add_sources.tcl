set lib_root $env(LIB_ROOT)

# Packages
read_verilog -sv [glob $lib_root/src/xilinx/ram/rtl/src/*_pkg.sv ]

# RTL
read_verilog -sv [glob $lib_root/src/xilinx/ram/rtl/src/*.sv ]

# Wrapper
read_verilog -sv xilinx_ram_sdp_lutram_wrapper.sv

# Constraints
read_xdc -unmanaged -mode out_of_context timing_ooc.xdc
read_xdc -unmanaged -ref xilinx_ram_sdp_lutram synth.xdc
