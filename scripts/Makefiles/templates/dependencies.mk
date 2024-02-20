# ----------------------------------------------------
# Dependencies
# ----------------------------------------------------

# Subomponents
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
#   with each element describing an RTL component using dot notation:
#
#   	[<library-name>.]<component-root.[<component-sub-name(s)>.]<subcomponent>
#
#   Implicit in each reference is that the RTL component can be compiled by
#   executing `make compile` at the path:
#
#       $(SRC_ROOT)/<component-root>[/<component-sub-name(s)..>]/<subcomponent>
#
#   within the RTL source library mapped to <library-name>.
#
#   e.g. a FIFO library exists in the source tree at $(SRC_ROOT)/fifo. The
#        library contains rtl/ verif/ and tb/ directories providing RTL,
#        verification and testbench subcomponents, respectively.
#
#        A downstream application that includes a FIFO instance from the
#        library would include the FIFO rtl component using the following
#        reference:
#
#            SUBCOMPONENTS = \
#                ... \
#                fifo.rtl
#
#        Similarly, the testbench for the application might include the verification
#        library using:
#
#            SUBCOMPONENTS = \
#                ... \
#                fifo.verif
#
#        These references resolve correctly assuming the FIFO and application are
#        co-located within the same library, i.e. at $(SRC_ROOT). RTL components from
#        'external' libraries can also be imported, using an '@' notation. For example,
#        the FIFO IP might be provided by a 'common' FPGA library that is imported into
#        the application. In this case it is necessary to also include the name used
#        by the application to map the common library. For example:
#
#            SUBCOMPMONENTS = \
#                ... \
#                fifo.rtl@common
#
SUBCOMPONENTS=

# Libraries
# ------------------
#    These are references to dependencies to static or third-party libraries that have
#    been pre-compiled.
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

