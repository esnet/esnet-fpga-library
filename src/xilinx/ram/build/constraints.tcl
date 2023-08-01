# Helper script to install all timing exceptions for Xilinx RAM library modules

# NOTE: assumes LIB_ROOT is defined and points to root of common library repository
# (Checked here)
if {![info exists env(LIB_ROOT)]} {
    puts "LIB_ROOT not defined; can't apply Xilinx RAM timing exceptions."
    exit 1;    
}

read_xdc -quiet -unmanaged -ref xilinx_ram_sdp_lutram $env(LIB_ROOT)/src/xilinx/ram/build/xilinx_ram_sdp_lutram/synth.xdc
