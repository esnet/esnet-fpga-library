# -------------------------------
# COMMAND-LINE ARGUMENTS
# -------------------------------
# phase (argument 0) [design phase to execute, i.e. proj/synth/opt/place/phys_opt/route]
set phase [lindex $argv 0]

# -------------------------------
# Global definitions
# (provided via environment variables)
# -------------------------------
# Set top-level module name
set top $env(TOP)

# Set project directory (if none is set, set to 'proj')
if {[info exists env(PROJ_DIR)]} {
    set PROJ_DIR $env(PROJ_DIR)
} else {
    set PROJ_DIR "proj"
}

# Set project name (if none is set, set to 'proj')
if {[info exists env(PROJ_NAME)]} {
    set PROJ_NAME $env(PROJ_NAME)
} else {
    set PROJ_NAME "proj"
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
if {$phase == "create_proj"} {
    puts ""
    puts "Creating OOC project $PROJ_FILE ..."
    puts ""
    vivadoProcs::create_proj $PART $top $PROJ_NAME $PROJ_DIR
    if {[info exists BOARD_PART]} {
        vivadoProcs::set_board_part $BOARD_PART
    }
    vivadoProcs::set_top $top
    config_ip_cache -disable_cache
    # Configure synthesis run
    vivadoProcs::config_synth_run
    set_property WRITE_INCREMENTAL_SYNTH_CHECKPOINT 1 [get_runs synth_1]
    # Configure implementation run
    vivadoProcs::config_impl_run
    # Clean up
    vivadoProcs::close_proj
} else {
    puts "Opening project $PROJ_FILE ..."
    puts ""
    vivadoProcs::open_proj $PROJ_NAME $PROJ_DIR
    if {[file exists $env(SOURCES_TCL_AUTO)]} {
        source $env(SOURCES_TCL_AUTO)
    } else {
        puts "WARNING: No sources specified ($env(SOURCES_TCL_AUTO) missing)."
    }
    if {[file exists $env(CONSTRAINTS_TCL_AUTO)]} {
        source $env(CONSTRAINTS_TCL_AUTO)
    } else {
        puts "WARNING: No synchronizer constraints specified ($env(CONSTRAINTS_TCL_AUTO) missing)."
    }
    if {[info exists $env(SOURCES_TCL_USER)]} {
        foreach sources_file $env(SOURCES_TCL_USER) {
            if {[file exists ${sources_file}]} {
                puts "Reading user source file ${sources_file}."
                source ${sources_file}
            }
        }
    }
    foreach xdc_file $env(CONSTRAINTS_XDC_USER) {
        if {[file exists ${xdc_file}]} {
            puts "Reading user constraint file ${xdc_file}."
            read_xdc -quiet -unmanaged -mode out_of_context ${xdc_file}
        }
    }

    # Perform specified operation
    switch $phase {
        gui {
            # Take no action
            # (used for loading sources only)
        }
        synth -
        opt -
        place {
            if {[get_property STATUS [get_runs synth_1]] == "synth_design Complete!" && [get_property NEEDS_REFRESH [get_runs synth_1]] == 0 } {
                puts "Synthesis for $top is up to date."
            } else {
                puts "Synthesizing $top ..."
                reset_run synth_1
                reset_run impl_1
                launch_runs -jobs 4 synth_1
                wait_on_runs synth_1
                open_run [get_runs synth_1]
                set_property HD.PARTITION 1 [current_design]
            }
            if { $phase != "synth" } {
                if {[get_property STATUS [get_runs impl_1]] == "Not started" || [get_property NEEDS_REFRESH [get_runs impl_1]] == 1} {
                    puts "Optimizing $top ..."
                    reset_run impl_1
                    launch_runs -jobs 4 -to_step opt_design impl_1
                    wait_on_runs impl_1
                } else {
                    puts "Optimization of $top is up to date."
                }
                if { $phase == "place"} {
                    if {[get_property CURRENT_STEP [get_runs impl_1]] != "place_design" && [get_property NEEDS_REFRESH [get_runs impl_1]] == 0} {
                        puts "Place design for $top is up to date."
                    } else {
                        puts "Placing $top ..."
                        launch_runs -jobs 4 -to_step place_design impl_1
                        wait_on_runs impl_1
                    }
                }
            }
        }
        default {
            puts "INVALID job: $phase (create_proj/synth/opt/place/gui)"
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
