set lib_root $env(LIB_ROOT)
set out_root $env(OUTPUT_ROOT)

# Packages
read_verilog -sv [glob $lib_root/src/reg/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/mem/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/sync/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/axi4l/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/xilinx/axi/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/fifo/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/std/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/db/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/htable/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/state/rtl/src/*_pkg.sv ]

read_verilog -sv [glob $out_root/state/build/state_vector_sram/rtl/src/*_pkg.sv ]

# RTL
read_verilog -sv [glob $lib_root/src/std/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/reg/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/sync/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/mem/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/axi4l/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/xilinx/axi/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/fifo/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/db/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/htable/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/state/rtl/src/*.sv ]

read_verilog -sv [glob $out_root/state/build/state_vector_sram/rtl/src/*.sv ]

# Top (wrapper)
read_verilog -sv state_vector_sram_wrapper.sv

# Constraints
read_xdc -unmanaged -mode out_of_context constraints/timing_ooc.xdc

source $lib_root/src/mem/build/constraints.tcl
source $lib_root/src/sync/build/constraints.tcl
