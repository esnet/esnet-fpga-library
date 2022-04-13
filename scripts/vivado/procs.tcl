namespace eval vivadoProcs {

    proc __create_proj {part proj_name proj_dir {ip 0}} { 
        if {$ip} {
            create_project $proj_name $proj_dir -part $part -force -ip
        } else {
            create_project $proj_name $proj_dir -part $part -force
        }
        set_property target_simulator XSim [current_project]
    }

    proc __open_proj {proj_name proj_dir} {
        open_project [file join $proj_dir $proj_name.xpr]
    }

    proc create_ip_proj {part {proj_name "ip_proj"} {proj_dir "[file join [pwd] ip_proj]"}} {
        if {[catch {__create_proj $part $proj_name $proj_dir 1} msg options]} {
            puts stderr "unexpected script error: $msg"
            if {[info exist env(DEBUG)]} {
                puts stderr "---- BEGIN TRACE ----"
                puts stderr [dict get $options -errorinfo]
                puts stderr "---- END TRACE ----"
            }

            # Reserve code 1 for "expected" error exits...
            exit 2
        }
    }

    proc create_proj {part top {proj_name "proj"} {proj_dir "[file join [pwd] proj]"}} {
        if {
            [catch {
                __create_proj $part $proj_name $proj_dir 0
                set_property top $top [current_fileset]
            } msg options]
        } {
            puts stderr "unexpected script error: $msg"
            if {[info exist env(DEBUG)]} {
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
            if {[info exist env(DEBUG)]} {
                puts stderr "---- BEGIN TRACE ----"
                puts stderr [dict get $options -errorinfo]
                puts stderr "---- END TRACE ----"
            }

            # Reserve code 1 for "expected" error exits...
            exit 2
        }
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

        # Run design phase
        # -----------------------------------------------
        eval ${phase}_design $topArg $modeArg $flattenArg

        # Mark as OOC as appropriate
        if ${ooc} {
            set_property HD.PARTITION 1 [current_design]
        }

        # Write DCP
        write_checkpoint -force $out_dir/$top.$phase.dcp

        # Write reports
        run_reports $top.$phase $out_dir
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
            phys_opt {
                read_checkpoint $out_dir/$top.place.dcp
            }
            route {
                read_checkpoint $out_dir/$top.phys_opt.dcp
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
            if {[info exist env(DEBUG)]} {
                puts stderr "---- BEGIN TRACE ----"
                puts stderr [dict get $options -errorinfo]
                puts stderr "---- END TRACE ----"
            }

            # Reserve code 1 for "expected" error exits...
            exit 2
        }
    }
}
