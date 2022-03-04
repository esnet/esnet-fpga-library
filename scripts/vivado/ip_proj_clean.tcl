set PROJ_FILE ${PROJ_DIR}/${PROJ_NAME}.xpr

if { [file exists $PROJ_FILE ] } {
    open_project $PROJ_FILE

    # Reset all targets
    reset_target {all} [get_ips *]

    close_project
}
