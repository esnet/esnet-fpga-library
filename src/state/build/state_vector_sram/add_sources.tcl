set lib_root $env(LIB_ROOT)
set out_root $env(OUTPUT_ROOT)

# Packages
read_verilog -sv [glob $lib_root/src/reg/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/mem/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/axi4l/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/xilinx/axi/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/fifo/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/std/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/db/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/htable/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/state/rtl/src/*_pkg.sv ]

read_verilog -sv [glob $out_root/fifo/regio/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $out_root/db/regio/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $out_root/htable/regio/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $out_root/state/regio/rtl/src/*_pkg.sv ]

# RTL
read_verilog -sv [glob $lib_root/src/std/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/reg/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/mem/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/axi4l/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/xilinx/axi/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/fifo/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/db/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/htable/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/state/rtl/src/*.sv ]

read_verilog -sv [glob $out_root/fifo/regio/rtl/src/*.sv ]
read_verilog -sv [glob $out_root/db/regio/rtl/src/*.sv ]
read_verilog -sv [glob $out_root/htable/regio/rtl/src/*.sv ]
read_verilog -sv [glob $out_root/state/regio/rtl/src/*.sv ]

# Top (wrapper)
read_verilog -sv state_vector_sram_wrapper.sv

# Constraints
read_xdc -unmanaged -mode out_of_context constraints/timing_ooc.xdc
