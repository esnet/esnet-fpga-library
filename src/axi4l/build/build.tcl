# -----------------------------------------------
# Defines
# -----------------------------------------------
set out_dir  .
set part     xcu280-fsvh2892-2L-e
set top      axi4l_decoder

# -----------------------------------------------
# Vivado synthesis flow
# -----------------------------------------------
# Set board/part
set_part $part
set_property board_part xilinx.com:au280:part0:1.1 [current_project]

# Design sources
source read_sources.tcl

# Generate IP output products
generate_target {synthesis} [get_ips]

# Synthesize IP OOC (out of context)
synth_ip [get_ips]

# Synthesize top level
synth_design -top $top -mode out_of_context

# Checkpoint
write_checkpoint -force $out_dir/post_synth

# Generate reports
report_timing_summary -file $out_dir/timing_summary.post_synth.rpt
report_utilization -file $out_dir/utilization.post_synth.rpt

save_project $top -force $out_dir

# Exit
exit
