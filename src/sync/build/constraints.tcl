# Helper script to install all timing exceptions for sync library modules

# NOTE: assumes LIB_ROOT is defined and points to root of common library repository
# (Checked here)
if {![info exists env(LIB_ROOT)]} {
    puts "LIB_ROOT not defined; can't apply sync timing exceptions."
    exit 1;    
}

read_xdc -quiet -unmanaged -ref sync_meta   $env(LIB_ROOT)/src/sync/build/sync_meta/synth.xdc
read_xdc -quiet -unmanaged -ref sync_areset $env(LIB_ROOT)/src/sync/build/sync_areset/synth.xdc
read_xdc -quiet -unmanaged -ref sync_bus    $env(LIB_ROOT)/src/sync/build/sync_bus/synth.xdc
