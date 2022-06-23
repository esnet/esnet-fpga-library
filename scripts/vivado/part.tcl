# Set board repo
if { [info exists env(BOARD_REPO)] } {
    if { [file exists $env(BOARD_REPO)] && [file isdirectory $env(BOARD_REPO)] } {
        set_param board.repoPaths $env(BOARD_REPO)
    } else {
        if { [string trim $env(BOARD_REPO)] != "" } {
            puts "WARNING: Couldn't find board repository at $env(BOARD_REPO). Using default repository."
        }
    }
}

# Set part
if { [info exists env(PART)] } {
    if { [string trim $env(PART)] != "" } {
        set PART $env(PART)
    } else {
        set PART [lindex [get_parts] 0]
        puts "WARNING: No part specified. Using default ($PART)."
    }
} else {
    set PART [lindex [get_parts] 0]
    puts "WARNING: No part specified. Using default ($PART)."
}

# Set board part
if { [info exists env(BOARD_PART)] } {
    if { [string trim $env(BOARD_PART)] != "" } {
        set BOARD_PART $env(BOARD_PART)
    }
}



