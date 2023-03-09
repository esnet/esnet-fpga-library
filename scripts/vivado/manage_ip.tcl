# -------------------------------
# COMMAND-LINE ARGUMENTS
# -------------------------------
# phase (argument 0) [design phase to execute, i.e. proj/create/generate/reset/status/upgrade/synth]
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
# Part configuration
# -------------------------------
# Config script should set:
# PART (FPGA device part)
# BOARD_PART (FPGA board designation, where applicable)

# -------------------------------
# Select/execute design phase
# -------------------------------
if {$phase == "proj"} {
    puts "Creating IP project $PROJ_FILE..."
    vivadoProcs::create_ip_proj $PART $PROJ_NAME $PROJ_DIR
    if {[info exists BOARD_PART]} {
        vivadoProcs::set_board_part $BOARD_PART
    }
    set xci_files [lindex $argv 1]
    add_files $xci_files
    vivadoProcs::close_proj
    puts "Done."
} else {
    vivadoProcs::create_ip_proj_in_memory $PART
    if {[info exists BOARD_PART]} {
        vivadoProcs::set_board_part $BOARD_PART
    }
    if {$phase == "create"} {
        set tcl_files [lindex $argv 1]
        foreach tcl_file $tcl_files {
            source $tcl_file
        }
    } else {
        set xci_files [lindex $argv 1]
        add_files $xci_files
        switch $phase {
            generate {
                generate_target all [get_ips]
                export_ip_user_files -of_objects [get_ips]
            }
            reset {
                reset_target -quiet all [get_ips]
            }
            synth {
                foreach ip [get_ips *] {
                    if {[get_property GENERATE_SYNTH_CHECKPOINT ${ip}]} {
                        synth_ip $ip
                    }
                }
            }
            exdes {
                open_example_project -force -dir . [get_ips] -in_process -quiet
            }
            drv_dpi {
                foreach ip [get_ips] {
                    generate_target example [get_ips $ip]
                    exec cp [glob -directory [file join $ip bin] *.so] $ip/
                    reset_target example [get_ips $ip]
                }
            }
            status {
                report_ip_status
            }
            upgrade {
                upgrade_ip [get_ips]
            }
            default {
                puts "INVALID IP job: $phase (create/proj/generate/reset/synth/exdes/drv_dpi/status/upgrade)"
            }
        }
    }
    vivadoProcs::close_proj
}

