# Non-project (batch-mode) build script.
# Handles synth, link, opt, place, place_opt, route, route_opt,
# bitstream, flash, device_image, and xsa phases.
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
#   -hook_tcl <file>         (link, implementation, and export: repeatable)
#   -ip_repo <path>          (synth+link: repeatable)
#   -out_dir <path>
#   -jobs <n>
#   -userid <val>           (bitstream USERID; also ::NP_USERID in export hooks)
#   -usr_access <val>       (bitstream USR_ACCESS)
#   -timestamp <val>        (silently consumed)
#   -board_part <val>       (board context for IP constraints)
#   -board_repo <path>      (additional board repository)
#   -cfgmem_size <MiB>      (flash capacity)
#   -cfgmem_interface <val> (flash interface, e.g. SPIx4)
#   -cfgmem_load_address <val> (bitstream address in flash)

# -------------------------------
# COMMAND-LINE ARGUMENTS
# -------------------------------
set PHASE [lindex $argv 0]
set TOP   [lindex $argv 1]

set PART            ""
set BOARD_PART      ""
set BOARD_REPO      ""
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
set USERID          ""
set USR_ACCESS      ""
set CFGMEM_SIZE     ""
set CFGMEM_INTERFACE ""
set CFGMEM_LOAD_ADDRESS ""

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
        -userid {
            set USERID [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -usr_access {
            set USR_ACCESS [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -board_part {
            set BOARD_PART [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -cfgmem_size {
            set CFGMEM_SIZE [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -cfgmem_interface {
            set CFGMEM_INTERFACE [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -cfgmem_load_address {
            set CFGMEM_LOAD_ADDRESS [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -board_repo {
            set BOARD_REPO [lindex $argv [expr {$i+1}]]
            incr i 2
        }
        -timestamp  -
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

# Board context must be available before IP sources or constraints are read.
proc setup_board_repository {board_repo} {
    if {[string trim $board_repo] eq ""} { return }
    if {![file isdirectory $board_repo]} {
        error "Board repository does not exist: $board_repo"
    }
    set repositories [get_param board.repoPaths]
    if {[lsearch -exact $repositories $board_repo] < 0} {
        set_param board.repoPaths [linsert $repositories 0 $board_repo]
    }
}

proc setup_board_part {board_part part} {
    if {[string trim $board_part] eq ""} { return }
    set board [get_board_parts -quiet $board_part]
    if {[llength $board] != 1} {
        error "Board part is unavailable or ambiguous: $board_part"
    }
    set board_device [get_property PART_NAME $board]
    if {$part ne "" && ![string equal -nocase $part $board_device]} {
        error "Board part '$board_part' selects device '$board_device', but '$part' was requested"
    }
    puts "Setting board part: $board_part"
    set_property board_part $board_part [current_project]
}

proc open_build_checkpoint {path} {
    open_checkpoint $path
    setup_board_part $::BOARD_PART $::PART
}

# -------------------------------
# Phase dispatch
# -------------------------------
setup_board_repository $BOARD_REPO
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

        setup_board_part $BOARD_PART $PART
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
        # Non-project flow uses create_project -in_memory (never saved) so
        # constraints can be managed — they embed into the synth DCP and
        # propagate through link and implementation automatically.
        set CONSTR_MGMT_TYPE {}
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

        setup_board_part $BOARD_PART $PART
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
        open_build_checkpoint $OUT_DIR/${TOP}.link.dcp
        source_hooks $HOOK_TCL "*opt.pre*"
        opt_design
        source_hooks $HOOK_TCL "*opt.post*"
        write_checkpoint -force $OUT_DIR/${TOP}.opt.dcp
        puts "Wrote: $OUT_DIR/${TOP}.opt.dcp"
    }

    place {
        open_build_checkpoint $OUT_DIR/${TOP}.opt.dcp
        set NP_PLACE_OPTS {}
        source_hooks $HOOK_TCL "*place.pre*"
        place_design {*}$NP_PLACE_OPTS
        write_checkpoint -force $OUT_DIR/${TOP}.place.dcp
        puts "Wrote: $OUT_DIR/${TOP}.place.dcp"
    }

    place_opt {
        open_build_checkpoint $OUT_DIR/${TOP}.place.dcp
        set NP_PLACE_OPT_OPTS {}
        source_hooks $HOOK_TCL "*place_opt.pre*"
        phys_opt_design {*}$NP_PLACE_OPT_OPTS
        write_checkpoint -force $OUT_DIR/${TOP}.place_opt.dcp
        puts "Wrote: $OUT_DIR/${TOP}.place_opt.dcp"
    }

    route {
        open_build_checkpoint $OUT_DIR/${TOP}.place_opt.dcp
        set NP_ROUTE_OPTS {}
        source_hooks $HOOK_TCL "*route.pre*"
        route_design {*}$NP_ROUTE_OPTS
        write_checkpoint -force $OUT_DIR/${TOP}.route.dcp
        puts "Wrote: $OUT_DIR/${TOP}.route.dcp"
    }

    route_opt {
        open_build_checkpoint $OUT_DIR/${TOP}.route.dcp
        set NP_ROUTE_OPT_OPTS {}
        source_hooks $HOOK_TCL "*route_opt.pre*"
        phys_opt_design {*}$NP_ROUTE_OPT_OPTS
        write_checkpoint -force $OUT_DIR/${TOP}.route_opt.dcp
        puts "Wrote: $OUT_DIR/${TOP}.route_opt.dcp"
        source_hooks $HOOK_TCL "*route_opt.post*"
    }

    bitstream -
    device_image {
        open_build_checkpoint $OUT_DIR/${TOP}.route_opt.dcp
        # Expose build context to programming-artifact hooks.
        set ::NP_TOP     $TOP
        set ::NP_OUT_DIR $OUT_DIR
        set ::NP_TOP_DCP $TOP_DCP
        set ::NP_USERID  $USERID
        if {$PHASE eq "bitstream"} {
            if {$USERID ne ""} {
                set_property BITSTREAM.CONFIG.USERID $USERID [current_design]
            }
            if {$USR_ACCESS ne ""} {
                set_property BITSTREAM.CONFIG.USR_ACCESS $USR_ACCESS [current_design]
            }
        }
        source_hooks $HOOK_TCL "*write_${PHASE}.pre*"
        if {$PHASE eq "bitstream"} {
            write_bitstream -force -bin_file $OUT_DIR/${TOP}.bit
            puts "Wrote: $OUT_DIR/${TOP}.bit"
            puts "Wrote: $OUT_DIR/${TOP}.bin"
        } else {
            write_device_image -force $OUT_DIR/${TOP}.pdi
            puts "Wrote: $OUT_DIR/${TOP}.pdi"
        }
        write_debug_probes -force $OUT_DIR/${TOP}.ltx
        puts "Wrote: $OUT_DIR/${TOP}.ltx"
        source_hooks $HOOK_TCL "*write_${PHASE}.post*"
    }

    flash {
        foreach setting {CFGMEM_SIZE CFGMEM_INTERFACE CFGMEM_LOAD_ADDRESS} {
            if {[set $setting] eq ""} {error "Flash export requires $setting"}
        }
        set bitfile [file join $OUT_DIR ${TOP}.bit]
        if {![file isfile $bitfile]} {error "Missing flash input bitstream: $bitfile"}
        write_cfgmem -force -format mcs -size $CFGMEM_SIZE \
            -interface $CFGMEM_INTERFACE \
            -loadbit [list up $CFGMEM_LOAD_ADDRESS $bitfile] \
            -file [file join $OUT_DIR ${TOP}.mcs]
        puts "Wrote: $OUT_DIR/${TOP}.mcs"
    }

    xsa {
        open_build_checkpoint $OUT_DIR/${TOP}.route_opt.dcp
        write_hw_platform -fixed -force -minimal \
            -file $OUT_DIR/${TOP}.xsa
        puts "Wrote: $OUT_DIR/${TOP}.xsa"
    }

    default {
        puts "ERROR: Unknown phase '$PHASE'."
        puts "Valid phases: synth link opt place place_opt route route_opt bitstream flash device_image xsa"
        exit 2
    }
}

puts ""
puts "Phase '$PHASE' complete."
