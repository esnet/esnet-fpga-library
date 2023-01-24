# -------------------------------
# COMMAND-LINE ARGUMENTS
# -------------------------------
# phase (argument 0) [design phase to execute, i.e. create/set]
set phase [lindex $argv 0]

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
vivadoProcs::create_ip_proj_in_memory $PART
if {[info exists BOARD_PART]} {
    vivadoProcs::set_board_part $BOARD_PART
}
set MODULE_NAME [lindex $argv 1]
switch $phase {
    create {
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
        if { $argc > 2 } {
            set MODULE_DIR [lindex $argv 2]
        } else {
            set MODULE_DIR $MODULE_NAME
        }
        read_ip [file join $MODULE_DIR $MODULE_NAME ${MODULE_NAME}.xci]
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
    exdes {
        if { $argc > 2 } {
            set MODULE_DIR [lindex $argv 2]
        } else {
            set MODULE_DIR $MODULE_NAME
        }
        read_ip [file join $MODULE_DIR $MODULE_NAME ${MODULE_NAME}.xci]
        # Generate example design
        open_example_project -force -dir $MODULE_DIR [get_ips $MODULE_NAME] -in_process -quiet
    }
    default {
        puts "INVALID job: $phase (create/drv_dpi)"
    }
}

