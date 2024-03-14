# -------------------------------
# COMMAND-LINE ARGUMENTS
# -------------------------------
# Phase (argument 0) [design phase to execute, i.e. create_proj/create_ip/ip/gui/sim/exdes/drv_dpi/sw_driver/synth/reset/status/upgrade]
set PHASE [lindex $argv 0]

# Optional arguments (expected to be specified in -name value pairs)
array set OPTIONS {
    -part                 ""
    -board_part           ""
    -board_repo           ""
    -proj_dir             ./ip_proj
    -proj_name            ip_proj
    -jobs                 8
    -ip                   {}
    -ip_tcl               {}
    -ip_xci               {}
}

for {set i 1} {$i < $argc} {incr i 2} {
    set argName [lindex $argv $i]
    set argValue [lindex $argv [expr $i+1]]
    if {[info exists OPTIONS($argName)]} {
        if {[lsearch {-ip_tcl -ip_xci -ip} $argName] >= 0} {
            lappend OPTIONS($argName) $argValue
        } else {
            set OPTIONS($argName) $argValue
        }
    } else {
        puts "WARNING: Ignoring unknown optional argument ${argName}."
    }
}
# Reformat options (flatten array, remove dash, convert to uppercase)
foreach {argName argValue} [array get OPTIONS] {
    set [string toupper [string range $argName 1 end]] $argValue
}

# -------------------------------
# Configure board repository
# -------------------------------
if { $BOARD_REPO != "" } {
    if {[file exists $BOARD_REPO] && [file isdirectory $BOARD_REPO]} {
        set_param board.repoPaths $BOARD_REPO
    } else {
        puts "WARNING: Couldn't find board repository at $BOARD_REPO. Using default repository."
    }
}
# -------------------------------
# Project definitions
# -------------------------------
set PROJ_FILE [file join $PROJ_DIR $PROJ_NAME.xpr]

# -------------------------------
# Select/execute design phase
# -------------------------------
if {$PHASE == "create_proj"} {
    puts ""
    puts "Creating IP project $PROJ_FILE ..."
    puts ""
    vivadoProcs::create_ip_proj $PART $PROJ_NAME $PROJ_DIR
    if {[string trim $BOARD_PART] != ""} {
        vivadoProcs::set_board_part $BOARD_PART
    }
    config_ip_cache -disable_cache
    vivadoProcs::close_proj
} elseif {$PHASE == "create_ip"} {
    vivadoProcs::create_ip_proj_in_memory $PART
    if {[string trim $BOARD_PART] != ""} {
        vivadoProcs::set_board_part $BOARD_PART
    }
    set ip_list []
    foreach tcl_file $IP_TCL {
        set ip [file rootname [file tail $tcl_file]]
        puts ""
        puts "Generating XCI for $ip ..."
        puts ""
        source $tcl_file
        puts "Done."
    }
    vivadoProcs::close_proj
} else {
    puts "Opening IP project $PROJ_FILE ..."
    puts ""
    switch $PHASE {
        gui -
        remove_ip -
        ip -
        sim -
        exdes -
        drv_dpi -
        sw_driver -
        synth -
        reset -
        upgrade {
            vivadoProcs::open_proj $PROJ_NAME $PROJ_DIR
            # Add IP that is not yet managed by the project
            foreach ip $IP {
                if {[lsearch -exact [get_ips] $ip] < 0} {
                    if {[file exists "$ip/$ip.xci"]} {
                        read_ip $ip/$ip.xci
                        puts "Added $ip to the IP project."
                    }
                }
            }
            # Remove unlisted IP from the project
            foreach ip [get_ips] {
                set ip_name [get_property NAME $ip]
                if {[lsearch -exact $IP $ip_name] < 0} {
                    remove_files [get_files [get_property IP_FILE $ip]]
                    puts "Removed ${ip_name} from the IP project."
                }
            }
        }
        default {
            vivadoProcs::open_proj_ro $PROJ_NAME $PROJ_DIR 
        }
    }
    # Perform specified operation
    switch $PHASE {
        gui -
        ip {
            # Take no action
        }
        remove_ip {
            foreach xci_file $IP_XCI {
                set ip [file rootname [file tail $xci_file]]
                if {[lsearch -exact [get_ips] $ip] < 0} {
                    puts "Warning: tried to remove $ip but $ip isn't managed by IP project."
                } else {
                    remove_files [get_files $xci_file]
                    puts "Removed $ip from the IP project."
                }
            }
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
            puts "INVALID IP job: $PHASE (create_proj/create_ip/ip/remove_ip/sim/exdes/drv_dpi/synth/reset/status/upgrade/gui)"
        }
    }
    switch $PHASE {
        gui {
            # Project opened in interactive mode; don't close
        }
        default {
            vivadoProcs::close_proj
        }
    }
}
