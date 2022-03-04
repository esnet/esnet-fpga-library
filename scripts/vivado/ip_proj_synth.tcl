set PROJ_FILE ${PROJ_DIR}/${PROJ_NAME}.xpr

if { [file exists $PROJ_FILE ] } {
    open_project $PROJ_FILE

    # Synthesize all IP
    foreach ip [get_ips] {
        if {[get_property GENERATE_SYNTH_CHECKPOINT ${ip}]} {
            synth_ip ${ip}
        }
    }

    close_project
}

