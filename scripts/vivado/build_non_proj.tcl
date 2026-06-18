# Non-project (batch-mode) build script for Versal V80.
# Handles all phases: synth, link, opt, place, place_opt, route, route_opt, device_image.
#
# Usage: vivado -source procs.tcl -source build_non_proj.tcl -mode batch \
#            -tclargs <phase> <top> [options...]
#
# Options:
#   -part <part>
#   -ooc 0|1              (synth only: OOC mode; default 0)
#   -top_dcp <path>       (link only: top-level DCP)
#   -cell_dcp <cell> <path>  (link only: repeatable)
#   -sources_tcl <file>      (synth only: repeatable)
#   -constraints_tcl <file>  (synth only: repeatable)
#   -constraints_xdc <file>  (link only: repeatable implementation XDC)
#   -hook_tcl <file>         (link+impl: repeatable)
#   -ip_repo <path>          (synth+link: repeatable)
#   -out_dir <path>
#   -jobs <n>
#   -timestamp <val>  -userid <val>  -usr_access <val>  (silently consumed)
#   -board_part <val>  -board_repo <val>  (silently consumed)

# -------------------------------
# COMMAND-LINE ARGUMENTS
# -------------------------------
set PHASE [lindex $argv 0]
set TOP   [lindex $argv 1]

set PART            ""
set OOC             0
set TOP_DCP         ""
set CELL_DCPS       {}
set SOURCES_TCL     {}
set CONSTRAINTS_TCL     {}
set CONSTRAINTS_XDC_SYNTH {}
set CONSTRAINTS_XDC     {}
set HOOK_TCL        {}
set IP_REPOS        {}
set OUT_DIR         [pwd]
set JOBS            4

set i 2
while {$i < $argc} {
    set arg [lindex $argv $i]
    switch $arg {
        -part {
            set PART [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -ooc {
            set OOC [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -top_dcp {
            set TOP_DCP [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -cell_dcp {
            set cell [lindex $argv [expr {$i+1}]]
            set dcp  [lindex $argv [expr {$i+2}]]
            lappend CELL_DCPS [list $cell $dcp]
            incr i 3
        }
        -sources_tcl {
            lappend SOURCES_TCL [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -constraints_tcl {
            lappend CONSTRAINTS_TCL [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -constraints_xdc_synth {
            lappend CONSTRAINTS_XDC_SYNTH [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -constraints_xdc {
            lappend CONSTRAINTS_XDC [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -hook_tcl {
            lappend HOOK_TCL [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -ip_repo {
            lappend IP_REPOS [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -out_dir {
            set OUT_DIR [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -jobs {
            set JOBS [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -board_part -
        -board_repo -
        -timestamp  -
        -userid     -
        -usr_access -
        -sources_tcl_auto -
        -constraints_tcl_auto -
        -proj_name  -
        -proj_dir   {
            incr i 2
        }
        default {
            if {[string index $arg 0] eq "-"} {
                puts "WARNING: Ignoring unknown flag and its value: $arg [lindex $argv [expr {$i+1}]]"
                incr i 2
            } else {
                puts "WARNING: Ignoring unexpected positional argument: $arg"
                incr i 1
            }
        }
    }
}

# -------------------------------
# Helpers
# -------------------------------

proc source_hooks {hook_list pattern} {
    foreach hook $hook_list {
        if {[string match $pattern [file tail $hook]]} {
            if {[file exists $hook]} {
                puts "Sourcing hook: $hook"
                source $hook
            } else {
                puts "WARNING: Hook file not found: $hook"
            }
        }
    }
}

proc setup_ip_repos {ip_repos} {
    if {[llength $ip_repos] == 0} { return }
    puts "Setting IP repo paths: $ip_repos"
    set_property ip_repo_paths $ip_repos [current_project]
    update_ip_catalog -quiet
}

# -------------------------------
# Phase dispatch
# -------------------------------
file mkdir $OUT_DIR

switch $PHASE {

    synth {
        # In-memory project for IP catalog / BD / fileset access.
        # No files are written to disk from this project.
        if {$PART ne ""} {
            create_project -in_memory -part $PART
        } else {
            create_project -in_memory
        }

        setup_ip_repos $IP_REPOS

        # Load auto-generated and user sources (read_bd, add_file, etc.)
        foreach tcl $SOURCES_TCL {
            if {[file exists $tcl]} {
                puts "Loading sources: $tcl"
                source $tcl
            } else {
                puts "WARNING: Sources TCL not found: $tcl"
            }
        }

        # Load synthesis constraints TCL (auto-generated ref-XDC, etc.)
        foreach tcl $CONSTRAINTS_TCL {
            if {[file exists $tcl]} {
                puts "Loading constraints: $tcl"
                source $tcl
            }
        }

        # Load synthesis XDC files (timing_ooc.xdc, etc.)
        foreach xdc $CONSTRAINTS_XDC_SYNTH {
            if {[file exists $xdc]} {
                puts "Loading synthesis XDC: $xdc"
                read_xdc $xdc
            } else {
                puts "WARNING: Synthesis XDC not found: $xdc"
            }
        }

        # Pre-generate BD output products before synthesis.
        set bd_files [get_files -quiet \
            -of_objects [get_filesets sources_1] \
            -filter {FILE_TYPE == "Block Designs"}]
        set bd_files [lsearch -all -inline -not -regexp $bd_files {/ip/}]
        if {[llength $bd_files] > 0} {
            puts "Pre-generating BD output products..."
            generate_target all $bd_files
        }

        # Run synthesis directly (non-project mode)
        if {$OOC} {
            puts "Running OOC synthesis: top=$TOP part=$PART"
            synth_design -top $TOP -part $PART -mode out_of_context
        } else {
            puts "Running synthesis: top=$TOP part=$PART"
            synth_design -top $TOP -part $PART
        }

        write_checkpoint -force $OUT_DIR/${TOP}.synth.dcp
        puts "Wrote: $OUT_DIR/${TOP}.synth.dcp"
    }

    link {
        # In-memory project for IP repo context needed by link_design
        # (CIPS partition resolution during validate_bd_design).
        if {$PART ne ""} {
            create_project -in_memory -part $PART
        } else {
            create_project -in_memory
        }

        setup_ip_repos $IP_REPOS

        # Read top-level DCP (shell synth result — full-device, core as black_box)
        puts "Reading top-level DCP: $TOP_DCP"
        read_checkpoint $TOP_DCP

        # Fill black_box cells from cell DCPs
        foreach cell_dcp_pair $CELL_DCPS {
            set cell [lindex $cell_dcp_pair 0]
            set dcp  [lindex $cell_dcp_pair 1]
            puts "Reading cell DCP: $cell <- $dcp"
            read_checkpoint -cell $cell $dcp
        }

        # Link in full-device mode (no -mode out_of_context)
        puts "Linking design: top=$TOP part=$PART"
        if {$PART ne ""} {
            link_design -top $TOP -part $PART
        } else {
            link_design -top $TOP
        }

        # Validate the BD design if one is present
        if {[llength [get_bd_designs -quiet]] > 0} {
            puts "Validating BD design..."
            validate_bd_design -quiet
        }

        source_hooks $HOOK_TCL "*link.post*"

        # Load implementation-only constraints
        foreach xdc $CONSTRAINTS_XDC {
            if {[file exists $xdc]} {
                puts "Loading constraint: $xdc"
                read_xdc $xdc
            } else {
                puts "WARNING: Constraint file not found: $xdc"
            }
        }

        write_checkpoint -force $OUT_DIR/${TOP}.link.dcp
        puts "Wrote: $OUT_DIR/${TOP}.link.dcp"
    }

    opt {
        open_checkpoint $OUT_DIR/${TOP}.link.dcp
        source_hooks $HOOK_TCL "*opt.pre*"
        opt_design
        source_hooks $HOOK_TCL "*opt.post*"
        write_checkpoint -force $OUT_DIR/${TOP}.opt.dcp
        puts "Wrote: $OUT_DIR/${TOP}.opt.dcp"
    }

    place {
        open_checkpoint $OUT_DIR/${TOP}.opt.dcp
        source_hooks $HOOK_TCL "*place.pre*"
        place_design
        write_checkpoint -force $OUT_DIR/${TOP}.place.dcp
        puts "Wrote: $OUT_DIR/${TOP}.place.dcp"
    }

    place_opt {
        open_checkpoint $OUT_DIR/${TOP}.place.dcp
        phys_opt_design
        write_checkpoint -force $OUT_DIR/${TOP}.place_opt.dcp
        puts "Wrote: $OUT_DIR/${TOP}.place_opt.dcp"
    }

    route {
        open_checkpoint $OUT_DIR/${TOP}.place_opt.dcp
        route_design
        write_checkpoint -force $OUT_DIR/${TOP}.route.dcp
        puts "Wrote: $OUT_DIR/${TOP}.route.dcp"
    }

    route_opt {
        open_checkpoint $OUT_DIR/${TOP}.route.dcp
        phys_opt_design
        write_checkpoint -force $OUT_DIR/${TOP}.route_opt.dcp
        puts "Wrote: $OUT_DIR/${TOP}.route_opt.dcp"
        source_hooks $HOOK_TCL "*route_opt.post*"
    }

    device_image {
        open_checkpoint $OUT_DIR/${TOP}.route_opt.dcp
        # Expose build context to hook scripts (e.g. write_device_image.pre.tcl)
        set ::NP_TOP     $TOP
        set ::NP_OUT_DIR $OUT_DIR
        set ::NP_TOP_DCP $TOP_DCP
        source_hooks $HOOK_TCL "*write_device_image.pre*"
        write_device_image -force $OUT_DIR/${TOP}.pdi
        puts "Wrote: $OUT_DIR/${TOP}.pdi"
        write_debug_probes -force $OUT_DIR/${TOP}.ltx
        puts "Wrote: $OUT_DIR/${TOP}.ltx"
    }

    xsa {
        open_checkpoint $OUT_DIR/${TOP}.route_opt.dcp
        write_hw_platform -fixed -force -minimal \
            -file $OUT_DIR/${TOP}.xsa
        puts "Wrote: $OUT_DIR/${TOP}.xsa"
    }

    default {
        puts "ERROR: Unknown phase '$PHASE'."
        puts "Valid phases: synth link opt place place_opt route route_opt device_image xsa"
        exit 2
    }
}

puts ""
puts "Phase '$PHASE' complete."
