# Apply design-wide XDC files and explicit reference-scoped XDC files.
# A requested reference must exist: a typo must not silently skip its waivers.
proc load_validation_waivers {args} {
    while {[llength $args]} {
        set argument [lindex $args 0]
        set args [lrange $args 1 end]
        if {$argument eq "-waiver-ref"} {
            if {[llength $args] < 2} {
                error "Expected reference and XDC path after -waiver-ref"
            }
            lassign $args reference waiver
            set args [lrange $args 2 end]
            # Vivado uniquifies references when instances need different netlists.
            set cells [get_cells -quiet -hierarchical -filter \
                [list REF_NAME == $reference || ORIG_REF_NAME == $reference]]
            if {![llength $cells]} {
                error "No instances of waiver reference '$reference' in the checkpoint"
            }
            puts "Loading waiver XDC: $waiver (reference=$reference, instances=[llength $cells])"
            read_xdc -ref $reference $waiver
        } else {
            read_xdc $argument
        }
    }
}
