# Register generated reference constraints before synthesis, then select XDCs
# against the elaborated hierarchy during LATE constraint processing.
namespace eval ::synthConstraints {
    proc load {script references} {
        if {[current_design -quiet] eq ""} {
            # Preserve the existing source entry point used by both build drivers
            # and external integrations. Vivado replays this Tcl constraint file
            # during elaboration and after synthesis, after clocks are defined.
            read_xdc {*}$::CONSTR_MGMT_TYPE $script
            # Managed read_xdc defaults to XDC parsing even for a .tcl file.
            set_property FILE_TYPE TCL [get_files $script]
            set_property PROCESSING_ORDER LATE [get_files $script]
            return
        }

        set top [get_property TOP [current_design]]
        foreach {ref xdc} $references {
            set registered [get_files -quiet $xdc]
            set active [expr {$top eq $ref || [llength [get_cells -quiet \
                -hierarchical -filter "REF_NAME == $ref || ORIG_REF_NAME == $ref"]]}]
            if {$active} {
                # Normal scoped-XDC processing resolves get_ports within each
                # instance and replays clock-dependent constraints correctly.
                # These registrations are local to the synthesis process; the
                # project saved before synthesis retains only the entry point.
                if {![llength $registered]} {
                    read_xdc -ref $ref $xdc
                }
                set_property PROCESSING_ORDER LATE [get_files $xdc]
            } elseif {[llength $registered]} {
                # A reference can disappear during synthesis optimization.
                remove_files $registered
            }
        }
    }
}
