# ===================================================
# CDC timing exceptions for sync_reset
# ===================================================
# NOTE: Timing exceptions contained in this XDC file are scoped to sync_reset instances.
#       This file should be included using:
#       read_xdc -unmanaged -ref sync_reset <path-to-common-lib>/sync/build/sync_reset/synth.xdc
set_false_path -quiet -to [get_pins __sync_ff_reset_n_reg[*]/CLR]
