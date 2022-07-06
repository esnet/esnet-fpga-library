# -------------------------------
# COMMAND-LINE ARGUMENTS
# -------------------------------
# phase (argument 0) [design phase to execute, i.e. create/set]
set phase [lindex $argv 0]

# -------------------------------
# Global definitions
# (provided via environment variables)
# -------------------------------
# Set IP project directory (if none is set, set to 'ip_proj')
if {[info exists env(IP_PROJ_DIR)]} {
    set PROJ_DIR $env(IP_PROJ_DIR)
} else {
    set PROJ_DIR "ip_proj"
}

# Set IP project name (if none is set, set to 'ip_proj')
if {[info exists env(IP_PROJ_NAME)]} {
    set PROJ_NAME $env(IP_PROJ_NAME)
} else {
    set PROJ_NAME "ip_proj"
}

set PROJ_FILE [file join $PROJ_DIR $PROJ_NAME.xpr]

# -------------------------------
# Configuration
# (provided by previously loaded config script)
# -------------------------------
# Config script should set:
# PART (FPGA device part)
# BOARD_PART (FPGA board designation, where applicable)

# -------------------------------
# Select/execute design phase
# -------------------------------
if { [file exists $PROJ_FILE ] } {
    vivadoProcs::open_proj $PROJ_NAME $PROJ_DIR
    switch $phase {
        create {
            set MODULE_NAME [lindex $argv 1]
            set P4_FILE [lindex $argv 2]
            set P4_OPTS [lindex $argv 3]
            if { $argc > 4 } {
                set MODULE_DIR [lindex $argv 4]
            } else {
                set MODULE_DIR $MODULE_NAME
            }
            set P4_PROPS [concat [list CONFIG.P4_FILE $P4_FILE] $P4_OPTS]
            create_ip -force -name vitis_net_p4 -vendor xilinx.com -library ip -module_name $MODULE_NAME -dir $MODULE_DIR
            set_property -dict $P4_PROPS [get_ips $MODULE_NAME]
        }
        drv_dpi {
            set MODULE_NAME [lindex $argv 1]
            if { $argc > 2 } {
                set MODULE_DIR [lindex $argv 2]
            } else {
                set MODULE_DIR $MODULE_NAME
            }
            if { $argc > 3 } {
                set VITISNETP4_DRV_DPI_DIR [lindex $argv 3]
            } else {
                set VITISNETP4_DRV_DPI_DIR [file join $MODULE_DIR $MODULE_NAME]
            }
            # Generate example target; causes dpi driver to be produced
            generate_target example [get_ips $MODULE_NAME]
            # Copy dpi driver to specified location
            exec mkdir -p $VITISNETP4_DRV_DPI_DIR
            exec cp [file join $MODULE_DIR $MODULE_NAME bin vitisnetp4_drv_dpi.so] $VITISNETP4_DRV_DPI_DIR
            # Reset example target to avoid conflicts due to example design xdc file
            reset_target example [get_ips $MODULE_NAME]
        }
        default {
            puts "INVALID job: $phase (create/drv_dpi)"
        }
    }
    vivadoProcs::close_proj
} else {
    puts "Managed IP project not available."
}

