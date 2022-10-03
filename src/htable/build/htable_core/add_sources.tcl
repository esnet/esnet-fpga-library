set lib_root $env(LIB_ROOT)

# Packages
read_verilog -sv [glob $lib_root/src/std/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/reg/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/mem/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/fifo/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/xilinx/axi/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/axi4l/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $lib_root/src/db/rtl/src/*_pkg.sv ]
read_verilog -sv [glob src/*_pkg.sv]
read_verilog -sv [glob ../../rtl/src/*_pkg.sv ]

# RTL
read_verilog -sv [glob $lib_root/src/std/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/util/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/reg/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/mem/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/fifo/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/axi4l/rtl/src/*.sv ]
read_verilog -sv [glob $lib_root/src/db/rtl/src/*.sv ]
read_verilog -sv [glob src/*.sv]
read_verilog -sv [glob ../../rtl/src/*.sv ]

# Wrapper
read_verilog -sv htable_core_wrapper.sv
# Constraints
read_xdc -unmanaged -mode out_of_context timing_ooc.xdc
