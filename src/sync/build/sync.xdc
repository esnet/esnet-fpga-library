# sync_level
set_false_path -to [get_cells -hier {__sync_level_ff_meta_reg[0]*}]

# sync_reset
set_false_path -to [get_pins -hier {__sync_reset_ff_meta_reg[*]*/CLR}]


