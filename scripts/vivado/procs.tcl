namespace eval vivadoProcs {

    proc __create_proj {part proj_name proj_dir {ip 0} {in_memory 0}} { 
        if {$ip} {
            if {$in_memory} {
                create_project $proj_name $proj_dir -part $part -force -ip -in_memory
            } else {
                create_project $proj_name $proj_dir -part $part -force -ip
            }
        } else {
            if {$in_memory} {
                create_project $proj_name $proj_dir -part $part -force -in_memory
            } else {
                create_project $proj_name $proj_dir -part $part -force
            }
        }
        set_property target_simulator XSim [current_project]
    }

    proc __open_proj {proj_name proj_dir} {
        open_project -quiet [file join $proj_dir $proj_name.xpr]
    }

    proc create_ip_proj {part {proj_name "ip_proj"} {proj_dir "[file join [pwd] ip_proj]"} {in_memory 0}} {
        if {[catch {__create_proj $part $proj_name $proj_dir 1 $in_memory} msg options]} {
            puts stderr "unexpected script error: $msg"
            if {[info exists env(DEBUG)]} {
                puts stderr "---- BEGIN TRACE ----"
                puts stderr [dict get $options -errorinfo]
                puts stderr "---- END TRACE ----"
            }

            # Reserve code 1 for "expected" error exits...
            exit 2
        }
    }

    proc create_ip_proj_in_memory {part {proj_name "ip_proj"} {proj_dir "[file join [pwd] ip_proj]"}} {
        create_ip_proj $part $proj_name $proj_dir 1
    }

    proc create_proj {part top {proj_name "proj"} {proj_dir "[file join [pwd] proj]"}} {
        if {
            [catch {
                __create_proj $part $proj_name $proj_dir 0
                set_property top $top [current_fileset]
            } msg options]
        } {
            puts stderr "unexpected script error: $msg"
            if {[info exists env(DEBUG)]} {
                puts stderr "---- BEGIN TRACE ----"
                puts stderr [dict get $options -errorinfo]
                puts stderr "---- END TRACE ----"
            }

            # Reserve code 1 for "expected" error exits...
            exit 2
        }
    }

    proc open_proj {{proj_name "proj"} {proj_dir "[file join [pwd] proj]"}} {
        if {[catch {__open_proj $proj_name $proj_dir} msg options]} {
            puts stderr "unexpected script error: $msg"
            if {[info exists env(DEBUG)]} {
                puts stderr "---- BEGIN TRACE ----"
                puts stderr [dict get $options -errorinfo]
                puts stderr "---- END TRACE ----"
            }

            # Reserve code 1 for "expected" error exits...
            exit 2
        }
    }

    proc close_proj {} {
        close_project
    }

    proc set_board_part {board_part} {
        set_property board_part $board_part [current_project]
    }

    proc run_reports {top out_dir} {
        report_timing -max_paths 1000 -file $out_dir/$top.timing.rpt
        report_timing_summary -file $out_dir/$top.timing.summary.rpt
        report_utilization -file $out_dir/$top.utilization.rpt
        report_utilization -hierarchical -file $out_dir/$top.utilization.hier.rpt
        report_design_analysis -logic_level_distribution -file $out_dir/$top.logic_levels.rpt
        report_cdc -details -file $out_dir/$top.cdc.rpt
        report_clock_interaction -file $out_dir/$top.clock_interaction.rpt
        report_qor_assessment -file $out_dir/$top.qor_assessment.rpt
        report_qor_suggestions -file $out_dir/$top.qor_suggestions.rpt
    }

    proc __run_phase {phase top ooc out_dir} {
        # Mode selection
        # -----------------------------------------------
        if ${ooc} {
            set mode "out_of_context"
        } else {
            set mode "default"
        }

        # Set top/mode for synth_design only
        if {$phase == "synth"} {
            set topArg "-top $top "
            set modeArg "-mode $mode"
            set flattenArg "-flatten_hierarchy rebuilt"
        } else {
            set topArg ""
            set modeArg ""
            set flattenArg ""
        }

        if {$phase == "bitstream"} {
            write_bitstream -force $out_dir/$top.bit
        } elseif {$phase == "mcs"} {
            write_cfgmem -force -format mcs -size 128 -interface SPIx4 -loadbit "up 0x1002000 $out_dir/$top.bit" -file "$out_dir/$top.mcs"
        } else {
            # Run design phase
            # -----------------------------------------------
            if {$phase == "place_opt" || $phase == "route_opt"} {
                set phase_name "phys_opt"
            } else {
                set phase_name $phase
            }
            eval ${phase_name}_design $topArg $modeArg $flattenArg

            # Mark as OOC as appropriate
            if ${ooc} {
                set_property HD.PARTITION 1 [current_design]
            }

            # Remove all 'macro' placement contraints (in order avoid conflicts with downstream pblock constraints).
            if {[llength [get_macros]]} {delete_macros [get_macros]}

            # Write DCP
            write_checkpoint -force $out_dir/$top.$phase.dcp

            # Write reports
            run_reports $top.$phase $out_dir
        }
    }

    proc __run_phase_incremental {phase top ooc out_dir} {
        # Read checkpoint from previous step
        switch $phase {
            synth {
                read_checkpoint $out_dir/$top.synth.dcp
            }
            opt {
                read_checkpoint $out_dir/$top.synth.dcp
            }
            place {
                read_checkpoint $out_dir/$top.opt.dcp
            }
            place_opt {
                read_checkpoint $out_dir/$top.place.dcp
            }
            route {
                read_checkpoint $out_dir/$top.place_opt.dcp
            }
            route_opt {
                read_checkpoint $out_dir/$top.route.dcp
            }
            bitstream {
                read_checkpoint $out_dir/$top.route_opt.dcp
            }
        }

        # Open design
        link_design -name $top

        # Execute design phase
        __run_phase $phase $top $ooc $out_dir
    }

    # Run specified design phase
    proc run_phase {phase top incremental {ooc 0} {out_dir [pwd]}} {
        if {
            [catch {
                if {$incremental} {
                    __run_phase_incremental $phase $top $ooc $out_dir
                } else {
                    __run_phase $phase $top $ooc $out_dir
                } 
            } msg options]
        } {
            puts stderr "unexpected script error: $msg"
            if {[info exists env(DEBUG)]} {
                puts stderr "---- BEGIN TRACE ----"
                puts stderr [dict get $options -errorinfo]
                puts stderr "---- END TRACE ----"
            }

            # Reserve code 1 for "expected" error exits...
            exit 2
        }
    }

}
