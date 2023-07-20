set lib_root $env(LIB_ROOT)
set out_root $env(OUTPUT_ROOT)

read_verilog -sv [glob $lib_root/src/std/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/sync/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/xilinx/axi/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/mem/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/axi4l/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/fifo/rtl/src/*_pkg.sv ]

read_verilog -sv [glob $out_root/fifo/regio/rtl/src/*_pkg.sv ]

read_verilog -sv [glob $lib_root/src/std/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/sync/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/reg/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/mem/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/axi4l/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/fifo/rtl/src/*.sv ]

read_verilog -sv [glob $out_root/fifo/regio/rtl/src/*.sv ]

read_verilog -sv [glob *.sv]

read_xdc -unmanaged timing_ooc.xdc
source $lib_root/src/mem/build/constraints.tcl
source $lib_root/src/sync/build/constraints.tcl
