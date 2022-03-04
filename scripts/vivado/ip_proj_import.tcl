set xci_files {}
foreach {ip} $ip_list {
    lappend xci_files [glob ${ip}/*.xci]
}

# Add IP by .xci specification
if {[string trim $xci_files] != ""} {
    add_files $xci_files
}

# Generate instantiation templates
generate_target {instantiation_template} [get_ips *]

