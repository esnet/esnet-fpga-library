create_project $PROJ_NAME $PROJ_DIR -part $PART -force -ip

set_property board_part $BOARD_PART [current_project]
set_property target_simulator XSim [current_project]
