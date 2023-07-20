# Helper script to install all timing exceptions for mem library modules

# NOTE: assumes LIB_ROOT is defined and points to root of common library repository
# (Checked here)
if {![info exists env(LIB_ROOT)]} {
    puts "LIB_ROOT not defined; can't apply mem timing exceptions."
    exit 1;    
}

read_xdc -quiet -unmanaged -ref mem_ram_sdp_async $env(LIB_ROOT)/src/mem/build/mem_ram_sdp_async/synth.xdc
