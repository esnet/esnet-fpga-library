# ----------------------------------------------------
# Dependencies
# ----------------------------------------------------

# Components
# ------------------
#
#   These are dependencies that represent components that are maintained within
#   the project repository and which can be compiled as needed using standard
#   make infrastructure.
#
#   These dependencies are typically those that are subject to modification,
#   i.e. custom or configurable IP that is internally managed (as opposed to
#   third-party or static IP that can [or must] be pre-compiled).
#
#   Component dependencies are described via space-separated list COMPONENTS,
#   with each element rovided in one of two forms:
#
#   1. 'internal' component reference
#       These refer to other components within the same
#       IP library. For example, a testbench could have
#       a dependency on the common verif library components.
#       This dependency is described simply as:
#
#       verif
#
#       Implicit in this reference is that there is a source directory
#       located at [ip_path]/verif that can be compiled into a simulation
#       library [ip_path]/verif/lib by executing 'make compile' at that
#       locati.
#
#   2. 'external' or fully-specified component reference
#       These refer to components outside the given IP library.
#       For example, a testbench could have a dependency on the AXI-L
#       verif libary components. Such a dependency could be described, e.g. as:
#
#       axil_verif=[path_to_axil_ip]/verif
#
#       Implicit in this reference is that the axil_verif library can be
#       compiled by executing 'make compile' at [path_to_axil_ip]/verif AND
#       that the resulting compiled simulation library will be named:
#       axil_verif.$(SIM_LIB_EXT) and located at [path_to_axil_ip]/verif/lib.
#
COMPONENTS=

# Libraries
# ------------------
#    These are references to dependencies to static or third-party
#    libraries that have been pre-compiled.
#
#    References should be in form:
#
#        lib_name
#
#        (applies to libraries in library path, e.g. Xilinx pre-compiled libraries)
#
#        OR
#
#        lib_name=lib_path
#
#        (applies to proprietary libraries, e.g. custom_ip_rtl=[path_to_custom_ip]/rtl/lib)
#
EXT_LIBS=

