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
    -proj_dir             ./bd_proj
    -proj_name            bd_proj
    -jobs                 8
    -ip_repo              {}
    -bd                   {}
    -bd_tcl               {}
    -bd_file              {}
}

for {set i 1} {$i < $argc} {incr i 2} {
    set argName [lindex $argv $i]
    set argValue [lindex $argv [expr $i+1]]
    if {[info exists OPTIONS($argName)]} {
        if {[lsearch {-bd_tcl -bd_file -bd -ip_repo} $argName] >= 0} {
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
    vivadoProcs::create_proj $PART $PROJ_NAME $PROJ_DIR
    if {[string trim $BOARD_PART] != ""} {
        vivadoProcs::set_board_part $BOARD_PART
    }
    vivadoProcs::close_proj
} elseif {$PHASE == "create_bd"} {
    vivadoProcs::create_proj_in_memory $PART
    if {[string trim $BOARD_PART] != ""} {
        vivadoProcs::set_board_part $BOARD_PART
    }
    # Configure IP repos
    foreach ip_repo $IP_REPO {
        set __ip_repos [get_property ip_repo_paths [current_project]]
        lappend __ip_repos $ip_repo
        set_property ip_repo_paths [lsort -unique ${__ip_repos}] [current_project]
    }
    update_ip_catalog
    # Create BD components
    set bd_list []
    foreach tcl_file $BD_TCL {
        set bd [file rootname [file tail $tcl_file]]
        puts ""
        puts "Generating BD for $bd ..."
        puts ""
        source $tcl_file
        puts "Done."
    }
    vivadoProcs::close_proj
} else {
    puts "Opening BD project $PROJ_FILE ..."
    puts ""
    switch $PHASE {
        gui -
        remove_bd -
        bd -
        sim -
        exdes -
        drv_dpi -
        sw_driver -
        synth -
        reset -
        upgrade {
            vivadoProcs::open_proj $PROJ_NAME $PROJ_DIR
            # Configure IP repos
            foreach ip_repo $IP_REPO {
                set __ip_repos [get_property ip_repo_paths [current_project]]
                lappend __ip_repos $ip_repo
                set_property ip_repo_paths [lsort -unique ${__ip_repos}] [current_project]
            }
            update_ip_catalog
            # Add IP that is not yet managed by the project
            foreach bd $BD {
                if {[lsearch -exact [get_bd_designs -quiet] $bd] < 0} {
                    if {[file exists "$bd/$bd.bd"]} {
                        read_bd $bd/$bd.bd
                        puts "Added $bd to the BD project."
                    }
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
        bd {
            # Take no action
        }
        remove_bd {
            foreach bd_file $BD_FILE {
                set bd [file rootname [file tail ${bd_file}]]
                if {[lsearch -exact [get_bd_designs -quiet] $bd] < 0} {
                    puts "Warning: tried to remove $bd but $bd isn't managed by BD project."
                } else {
                    remove_files [get_files ${bd_file}]
                    puts "Removed $bd from the BD project."
                }
            }
        }
        sim {
            foreach bd_file $BD_FILE {
                reset_target -quiet {simulation} [get_files ${bd_file}]
                generate_target {simulation} [get_files ${bd_file}]
                export_ip_user_files -quiet -of_objects [get_files ${bd_file}]
            }
        }
        synth {
            set synth_runs {}
            foreach bd_file $BD_FILE {
                set bd [file rootname [file tail ${bd_file}]]
                set synth_run ${bd}_synth_1
                vivadoProcs::set_top ${bd}
                if {[llength [get_runs $synth_run]] > 0} {
                    if {[get_property CURRENT_STEP [get_runs $synth_run]] == "synth_design" && [get_property NEEDS_REFRESH [get_runs $synth_run]] == 0} {
                        puts "Synthesis products for $bd are up to date."
                    } else {
                        puts "Synthesizing BD $bd ..."
                        reset_target -quiet {synthesis implementation} [get_files ${bd_file}]
                        generate_target {synthesis implementation} [get_files ${bd_file}]
                        reset_run ${bd}_synth_1
                        lappend synth_runs ${bd}_synth_1
                    }
                } else {
                    puts "Synthesizing BD $bd ..."
                    generate_target {synthesis implementation} [get_files ${bd_file}]
                    create_run -flow {Vivado Synthesis 2023} ${bd}_synth_1
                    vivadoProcs::config_synth_run ${bd}_synth_1 1
                    lappend synth_runs ${bd}_synth_1
                }
                launch_runs -jobs 1 ${bd}_synth_1
            }
            if {[llength $synth_runs] > 0} {
                wait_on_runs $synth_runs
            }
        }
        reset {
            foreach bd_file $BD_FILE {
                reset_target -quiet all [get_files ${bd_file}]
            }
        }
        status {
            report_ip_status
        }
        default {
            puts "INVALID IP job: $PHASE (create_proj/create_bd/bd/remove_bd/sim/synth/reset/status/gui)"
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
