# ===================================================
# CDC timing exceptions for sync_areset
# ===================================================
# NOTE: Timing exceptions contained in this XDC file are scoped to sync_areset instances.
#       This file should be included using:
#       read_xdc -ref sync_areset <path-to-common-lib>/sync/build/sync_areset/synth.xdc
set_false_path -quiet -to [get_pins __sync_ff_reset_n_reg[*]/CLR]
