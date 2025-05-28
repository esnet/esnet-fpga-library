# Script to check that license exists for specified IP description (e.g. xilinx.com:ip:clk_wiz:6.0)

# IP descriptions are provided as Tcl arguments

# Create dummy project
create_project -in_memory

set fail 0
foreach {ipdef_plus_core_rev} $argv {
    lassign [split $ipdef_plus_core_rev "="] ipdef core_rev
    if {[llength [get_ipdefs $ipdef]]} {
        if {[get_property REQUIRES_LICENSE [get_ipdefs $ipdef]]} {
            set lic_keys [get_property LICENSE_KEYS [get_ipdefs $ipdef]]
            if {[llength $lic_keys]} {
                puts "License keys found for ${ipdef}: $lic_keys."
            } else {
                puts "WARNING: License key not found for ${ipdef}."
                set fail 1;
            }
        } else {
            puts "No license file needed for ${ipdef}."
        }
        set core_rev_actual [get_property CORE_REVISION [get_ipdefs $ipdef]]
        if {$core_rev_actual != $core_rev} {
            puts "WARNING: configured core revision ($core_rev) for $ipdef differs from actual core revision ($core_rev_actual)"
        }
    } else {
        puts "WARNING: IP definition $ipdef not found."
        set fail 1;
    }
}
exit $fail

