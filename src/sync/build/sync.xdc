# sync_level
set_false_path -quiet -to [get_cells -hier {__sync_level_ff_meta_reg[0]*}]

# sync_bus
set_false_path -quiet -to [get_cells -hier {__sync_bus_ff_data*}]

# sync_reset
set_false_path -quiet -to [get_pins -hier {__sync_reset_ff_meta_reg[*]*/CLR}]




