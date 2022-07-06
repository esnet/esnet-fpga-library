# -------------------------------
# COMMAND-LINE ARGUMENTS
# -------------------------------
# phase (argument 0) [design phase to execute, i.e. create/import/clean]
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
if {$phase == "create"} {
    puts "Creating IP project $PROJ_FILE..."
    vivadoProcs::create_ip_proj $PART $PROJ_NAME $PROJ_DIR
    if {[info exists BOARD_PART]} {
        vivadoProcs::set_board_part $BOARD_PART
    }
    vivadoProcs::close_proj
    puts "Done."
} else {
    if { [file exists $PROJ_FILE ] } {
        vivadoProcs::open_proj $PROJ_NAME $PROJ_DIR
        switch $phase {
            import {
                set xci_files [lindex $argv 1]
                foreach xci_file $xci_files {
                    if {[llength [get_files -quiet $xci_file]] > 0} {
                        puts "IP already present ($xci_file). Skipping import."
                    } else {
                        puts "Adding $xci_file..."
                        read_ip $xci_files
                    }
                }
            }
            generate {
                if {$argc > 1} {
                    set target [lindex $argv 1]
                } else {
                    set target all
                }
                if {$argc > 2} {
                    set ips [get_ips [lindex $argv 2]]
                } else {
                    set ips [get_ips *]
                }
                generate_target $target $ips
            }
            synth {
                if {$argc > 1} {
                    set ips [get_ips [lindex $argv 1]]
                } else {
                    set ips [get_ips *]
                }
                foreach ip $ips {
                    if {[get_property GENERATE_SYNTH_CHECKPOINT ${ip}]} {
                        synth_ip $ip
                    }
                }
            }
            reset {
                if {$argc > 1} {
                    set target [lindex $argv 1]
                } else {
                    set target all
                }
                reset_target -quiet $target [get_ips *]
            }
            status {
                report_ip_status
            }
            default {
                puts "INVALID IP job: $phase (create/import/generate/synth/reset/status)"
            }
        }
        vivadoProcs::close_proj
    } else {
        puts "Managed IP project not available."
    }
}

