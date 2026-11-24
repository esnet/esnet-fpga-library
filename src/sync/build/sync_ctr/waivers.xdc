# Validation-only CDC-6 waiver scoped to sync_ctr, not general sync_meta buses.
# The source registers Gray-encoded data before the destination ASYNC_REG chain.
# Callers must obey the documented single-count-per-source-cycle contract and
# coordinate resets. The sync_meta max-delay and bus-skew constraints still apply.
# Load with read_xdc -ref sync_ctr; do not waive arbitrary multi-bit synchronizers.
# XPM_CDC_GRAY uses the same CDC-6 waiver mechanism in Vivado 2025.2.
create_waiver -scoped -type CDC -id CDC-6 -user esnet \
    -description {Registered Gray counter transfer through the sync_ctr synchronizer} \
    -from [get_pins -hierarchical -filter {NAME =~ *sync_meta_0/g__input_reg.__sync_ff_in_reg*/C}] \
    -to [get_pins -hierarchical -regexp {.*sync_meta_0/__sync_ff_meta_reg\[0\](\[[0-9]+\])?/D}]
