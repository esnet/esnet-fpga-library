set proj_root $env(PROJ_ROOT)

# Packages
read_verilog -sv [glob $proj_root/src/library/reg/rtl/src/*_pkg.sv ]
read_verilog -sv [glob $proj_root/src/library/mem/rtl/src/*_pkg.sv ]
read_verilog -sv [glob src/*_pkg.sv]
read_verilog -sv [glob $proj_root/src/library/std/rtl/src/*_pkg.sv ]
read_verilog -sv [glob ../rtl/src/*_pkg.sv ]

# RTL
read_verilog -sv [glob $proj_root/src/library/std/rtl/src/*.sv ]
read_verilog -sv [glob $proj_root/src/library/reg/rtl/src/*.sv ]
read_verilog -sv [glob $proj_root/src/library/mem/rtl/src/*.sv ]
read_verilog -sv [glob src/*.sv]
read_verilog -sv [glob ../rtl/src/*.sv ]

# Constraints
read_xdc -unmanaged -mode out_of_context constraints/timing_ooc.xdc
