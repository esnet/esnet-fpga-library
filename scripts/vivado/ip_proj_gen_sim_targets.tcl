set PROJ_FILE ${PROJ_DIR}/${PROJ_NAME}.xpr

if { [file exists $PROJ_FILE ] } {
    open_project $PROJ_FILE

    # Generate simulation products
    generate_target {simulation} [get_ips *]

    close_project
}

