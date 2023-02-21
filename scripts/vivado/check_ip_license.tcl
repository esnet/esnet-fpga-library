# Script to check that license exists for specified IP description (e.g. xilinx.com:ip:clk_wiz:6.0)

# IP descriptions are provided as Tcl arguments

# Create dummy project
create_project -in_memory

foreach {ipdef} $argv {
    if {[llength [get_ipdefs $ipdef]]} {
        if {[get_property REQUIRES_LICENSE [get_ipdefs $ipdef]]} {
            set lic_keys [get_property LICENSE_KEYS [get_ipdefs $ipdef]]
            if {[llength $lic_keys]} {
                puts "License keys found for ${ipdef}: $lic_keys."
            } else {
                puts "ERROR: License key not found for ${ipdef}." 
                exit 1;
            }
        } else {
            puts "No license file needed for ${ipdef}. OK."
        }
    } else {
        puts "IP definition $ipdef not found."
        exit 1;
    }
}

