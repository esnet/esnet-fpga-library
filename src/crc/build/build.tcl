# -----------------------------------------------
# Defines
# -----------------------------------------------
set out_dir  .
set part     xcu280-fsvh2892-2L-e
set top      crc32_x64

# -----------------------------------------------
# Vivado synthesis flow
# -----------------------------------------------
# Set board/part
set_part $part
set_property board_part xilinx.com:au280:part0:1.1 [current_project]

# Design sources
source read_sources.tcl

# Add top-level constraints
read_xdc timing.xdc

# Synthesize top level
synth_design -top $top -mode out_of_context

# Checkpoint
write_checkpoint -force $out_dir/synth

# Generate reports
report_timing -max_paths 1000 -file $out_dir/$top.timing.synth.rpt
report_timing_summary -file $out_dir/$top.timing.summary.synth.rpt
report_utilization -file $out_dir/$top.utilization.synth.rpt
report_utilization -hierarchical -file $out_dir/$top.utilization.hier.synth.rpt
report_design_analysis -logic_level_distribution -file $out_dir/$top.logic_levels.synth.rpt

# Exit
exit
