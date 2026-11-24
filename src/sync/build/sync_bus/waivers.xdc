# Validation-only handshake payload waiver; load with read_xdc -ref sync_bus.
# Accepted payloads are held until the destination captures them and its
# acknowledgment returns. Initialize both domains before transfers; coordinate
# resets when abandoning an in-flight transfer. The request/acknowledgment
# synchronizers and payload max-delay/bus-skew constraints must remain active.
# Only the direct payload-register crossing is waived, not handshake controls
# or arbitrary clock-enable-controlled buses. See the sync README for details.
create_waiver -scoped -type CDC -id CDC-15 -user esnet \
    -description {Stable sync_bus payload transferred under a synchronized request/acknowledgment handshake} \
    -from [get_pins -hierarchical -filter {NAME =~ *__sync_ff_bus_data_in_reg*/C}] \
    -to [get_pins -hierarchical -filter {NAME =~ *__sync_ff_bus_data_out_reg*/D}]
