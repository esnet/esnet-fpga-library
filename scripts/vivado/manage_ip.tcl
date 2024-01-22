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
if {$phase == "create_proj"} {
    puts ""
    puts "Creating IP project $PROJ_FILE..."
    puts ""
    vivadoProcs::create_ip_proj $PART $PROJ_NAME $PROJ_DIR
    if {[info exists BOARD_PART]} {
        vivadoProcs::set_board_part $BOARD_PART
    }
    vivadoProcs::close_proj
} elseif {$phase == "create_ip"} {
    vivadoProcs::create_ip_proj_in_memory $PART
    if {[info exists BOARD_PART]} {
        vivadoProcs::set_board_part $BOARD_PART
    }
    set ip_list []
    set tcl_files [lindex $argv 1]
    foreach tcl_file $tcl_files {
        set ip [file rootname [file tail $tcl_file]]
        puts ""
        puts "Generating XCI for $ip ..."
        puts ""
        source $tcl_file
        puts "Done."
    }
    vivadoProcs::close_proj
} else {
    puts "Opening IP project $PROJ_FILE..."
    puts ""
    switch $phase {
        ip -
        gui -
        sim -
        exdes -
        drv_dpi -
        sw_driver -
        synth -
        reset -
        upgrade {
            vivadoProcs::open_proj $PROJ_NAME $PROJ_DIR
        }
        default {
            vivadoProcs::open_proj_ro $PROJ_NAME $PROJ_DIR 
        }
    }
    # Add new XCI files
    set xci_files [lindex $argv 1]
    foreach xci_file $xci_files {
        set ip [file rootname [file tail $xci_file]]
        if {[lsearch -exact [get_ips] $ip] < 0} {
            read_ip $xci_file
            puts "Added $ip to the IP project."
        } elseif {[get_property IS_LOCKED [get_ips $ip]]} {
            upgrade_ip [get_ips $ip]
            export_ip_user_files -of_objects [get_ips $ip] -sync -force -quiet
        }
    }
    # Perform specified operation
    switch $phase {
        ip -
        gui {
            # Take no action
            # (used for loading IP from XCI files only)
        }
        sim {
            reset_target -quiet {simulation instantiation_template} [get_ips]
            generate_target {simulation instantiation_template} [get_ips]
            export_ip_user_files -quiet -of_objects [get_ips]
        }
        exdes {
            open_example_project -force -dir . [get_ips] -in_process -quiet
        }
        drv_dpi {
            foreach ip [get_ips] {
                generate_target example [get_ips $ip]
                file copy -force [glob -directory [file join $ip bin] *.so] $ip/
                reset_target example [get_ips $ip]
            }
        }
        sw_driver {
            reset_target -quiet {sw_driver} [get_ips]
            generate_target {sw_driver} [get_ips]
        }
        synth {
            set ip_runs {}
            foreach ip [get_ips] {
                set ip_run ${ip}_synth_1
                if {[llength [get_runs $ip_run]] > 0} {
                    if {[get_property CURRENT_STEP [get_runs $ip_run]] == "synth_design" && [get_property NEEDS_REFRESH [get_runs $ip_run]] == 0} {
                        puts "Synthesis products for $ip are up to date."
                    } else {
                        puts "Synthesizing IP $ip ..."
                        reset_target -quiet {synthesis implementation} [get_ips $ip]
                        generate_target {synthesis implementation} [get_ips $ip]
                        reset_run ${ip}_synth_1
                        lappend ip_runs ${ip}_synth_1
                    }
                } else {
                    puts "Synthesizing IP $ip ..."
                    generate_target {synthesis implementation} [get_ips $ip]
                    create_ip_run [get_ips $ip]
                    lappend ip_runs ${ip}_synth_1
                }
            }
            if {[llength $ip_runs] > 0} {
                launch_runs -jobs 4 $ip_runs
                wait_on_runs $ip_runs
            }
        }
        reset {
            reset_target -quiet all [get_ips]
        }
        status {
            report_ip_status
        }
        upgrade {
            upgrade_ip [get_ips]
        }
        default {
            puts "INVALID IP job: $phase (create_proj/create_ip/sim/exdes/drv_dpi/synth/reset/status/upgrade)"
        }
    }
    switch $phase {
        gui {
            # Project opened in interactive mode; don't close
        }
        default {
            vivadoProcs::close_proj
        }
    }
}
