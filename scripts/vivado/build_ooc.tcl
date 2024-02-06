# -------------------------------
# COMMAND-LINE ARGUMENTS
# -------------------------------
# phase (argument 0) [design phase to execute, i.e. init/synth/opt/place/phys_opt/route]
set phase [lindex $argv 0]

# incremental (argument 1) [flag indicating whether design phase should be executed incrementally]
if {$argc > 1} {
    set incremental [lindex $argv 1]
} else {
    set incremental 0
}

# -------------------------------
# Global definitions
# (provided via environment variables)
# -------------------------------
# Set top-level module name
set top $env(TOP)

# Set output directory (if none is set, set to 'out')
if {[info exists env(BUILD_OUTPUT_DIR)]} {
    set out_dir $env(BUILD_OUTPUT_DIR)
} else {
    set out_dir out
}

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
if {!$incremental} {
    puts "Initializing design..."
    if {[info exists PART]} {
        set_part $PART
    }
    if {[info exists BOARD_PART]} {
        set_property board_part $BOARD_PART [current_project]
        puts "-- Board part set to $BOARD_PART"
    }
    if {[file exists $env(SOURCES_TCL_AUTO)]} {
        source $env(SOURCES_TCL_AUTO)
    } else {
        puts "WARNING: No sources specified ($env(SOURCES_TCL_AUTO) missing)."
    }
    if {[file exists $env(CONSTRAINTS_TCL_AUTO)]} {
        source $env(CONSTRAINTS_TCL_AUTO)
    } else {
        puts "WARNING: No synchronizer constraints specified ($env(CONSTARINTS_TCL_AUTO) missing)."
    }
    if {[file exists $env(SOURCES_TCL_USER)]} {
        source $env(SOURCES_TCL_USER)
    }
}
puts "Executing ${phase}_design..."
vivadoProcs::run_phase $phase $top $incremental 1 $out_dir

