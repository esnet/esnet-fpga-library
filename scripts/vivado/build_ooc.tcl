# -------------------------------
# COMMAND-LINE ARGUMENTS
# -------------------------------
# phase (argument 0) [design phase to execute, i.e. proj/synth/opt/place/phys_opt/route]
set PHASE [lindex $argv 0]

# top-level module name (argument 1)
set TOP [lindex $argv 1]

# Optional arguments (expected to be specified in -name value pairs)
array set OPTIONS {
    -part                 ""
    -board_part           ""
    -board_repo           ""
    -proj_dir             ./proj
    -proj_name            proj
    -jobs                 8
    -sources_tcl_auto     synth/sources.tcl
    -constraints_tcl_auto synth/constraints.tcl
    -sources_tcl          {}
    -constraints_xdc      {}
}

for {set i 2} {$i < $argc} {incr i 2} {
    set argName [lindex $argv $i]
    set argValue [lindex $argv [expr $i+1]]
    if {[info exists OPTIONS($argName)]} {
        if {[lsearch {-sources_tcl -constraints_xdc} $argName] >= 0} {
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
# Part configuration
# (provided by previously loaded config script)
# -------------------------------
# Config script should set:
# PART (FPGA device part)
# BOARD_PART (FPGA board designation, where applicable)

# -------------------------------
# Select/execute design phase
# -------------------------------
if {$PHASE == "create_proj"} {
    puts ""
    puts "Creating OOC project $PROJ_FILE ..."
    puts ""
    if {[string trim $PART] == ""} {
        puts "ERROR: No part specified. Could not create project."
        exit 2
    }
    vivadoProcs::create_proj $PART $TOP $PROJ_NAME $PROJ_DIR
    if {[string trim $BOARD_PART] != ""} {
        vivadoProcs::set_board_part $BOARD_PART
    }
    vivadoProcs::set_top $TOP
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
    # Validate part/board part
    if {[string toupper [vivadoProcs::get_part]] != [string toupper $PART]} {
        puts "ERROR: specified part ($PART) is different from project part ([vivadoProcs::get_part])."
        exit 2
    }
    if {[string toupper [vivadoProcs::get_board_part]] != [string toupper $BOARD_PART]} {
        puts "ERROR: specified board part ($BOARD_PART) is different from project board part ([vivadoProcs::get_board_part])."
        exit 2
    }
    # Load sources and constraints
    if {[file exists $SOURCES_TCL_AUTO]} {
        source $SOURCES_TCL_AUTO
    } else {
        puts "WARNING: No sources specified ($SOURCES_TCL_AUTO missing)."
    }
    if {[file exists $CONSTRAINTS_TCL_AUTO]} {
        source $CONSTRAINTS_TCL_AUTO
    } else {
        puts "WARNING: No synchronizer constraints specified ($CONSTRAINTS_TCL_AUTO missing)."
    }
    foreach sources_file $SOURCES_TCL {
        if {[file exists ${sources_file}]} {
            puts "Reading user source file ${sources_file}."
            source ${sources_file}
        }
    }
    foreach xdc_file $CONSTRAINTS_XDC {
        if {[file exists ${xdc_file}]} {
            puts "Reading user constraint file ${xdc_file}."
            read_xdc -quiet -unmanaged -mode out_of_context ${xdc_file}
        }
    }
    vivadoProcs::set_top $TOP

    # Perform specified operation
    switch $PHASE {
        gui {
            # Take no action
            # (used for loading sources only)
        }
        synth -
        opt -
        place {
            if {[get_property STATUS [get_runs synth_1]] == "synth_design Complete!" && [get_property NEEDS_REFRESH [get_runs synth_1]] == 0 } {
                puts "Synthesis for $TOP is up to date."
            } else {
                puts "Synthesizing $TOP ..."
                reset_run synth_1
                reset_run impl_1
                launch_runs -jobs $JOBS synth_1
                wait_on_runs synth_1
                open_run [get_runs synth_1]
                set_property HD.PARTITION 1 [current_design]
            }
            if { $PHASE != "synth" } {
                if {[get_property STATUS [get_runs impl_1]] == "Not started" || [get_property NEEDS_REFRESH [get_runs impl_1]] == 1} {
                    puts "Optimizing $TOP ..."
                    reset_run impl_1
                    launch_runs -jobs $JOBS -to_step opt_design impl_1
                    wait_on_runs impl_1
                } else {
                    puts "Optimization of $TOP is up to date."
                }
                if { $PHASE == "place"} {
                    if {[get_property CURRENT_STEP [get_runs impl_1]] != "place_design" && [get_property NEEDS_REFRESH [get_runs impl_1]] == 0} {
                        puts "Place design for $TOP is up to date."
                    } else {
                        puts "Placing $TOP ..."
                        launch_runs -jobs $JOBS -to_step place_design impl_1
                        wait_on_runs impl_1
                    }
                }
            }
        }
        default {
            puts "INVALID job: $PHASE (create_proj/synth/opt/place/gui)"
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
