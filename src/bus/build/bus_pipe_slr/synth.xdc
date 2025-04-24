# ===================================================
# SLR crossing constraints
# ===================================================
set_property USER_SLL_REG TRUE [get_cells i_bus_slr_tx/*reg*]
set_property USER_SLL_REG TRUE [get_cells i_bus_slr_rx/*reg*]
set_property USER_CROSSING_SLR TRUE [get_pins {i_bus_slr_tx/srst*/Q i_bus_slr_tx/data*/Q i_bus_slr_tx/valid*/Q i_bus_slr_tx/*ready*/D}]
set_property USER_CROSSING_SLR TRUE [get_pins {i_bus_slr_rx/srst*/D i_bus_slr_rx/data*/D i_bus_slr_rx/valid*/D i_bus_slr_rx/*ready*/Q}]

# Example for assigning Tx/Rx sides of SLR crossing component to
# different SLRs
# set_property USER_SLR_ASSIGNMENT SLR0 [get_cells i_bus_pipe_tx]
# set_property USER_SLR_ASSIGNMENT SLR0 [get_cells i_bus_slr_tx]
# set_property USER_SLR_ASSIGNMENT SLR1 [get_cells i_bus_slr_rx]
# set_property USER_SLR_ASSIGNMENT SLR1 [get_cells i_bus_pipe_rx]
