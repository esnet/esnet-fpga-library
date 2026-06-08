# -----------------------------------------------
# Configuration
# -----------------------------------------------
REGRESSION = 0
SEED ?= 0
waves ?= OFF

# ----------------------------------------------------
# Additional dependencies beyond axi4l test_base.mk
# ----------------------------------------------------
SUBCOMPONENTS += \
    axi4.pkg \
    axi4.rtl \
    axi4.verif

# ----------------------------------------------------
# Defines / plusargs / options
# ----------------------------------------------------
override DEFINES +=
override PLUSARGS +=
COMPILE_OPTS =
ELAB_OPTS =
SIM_OPTS =

# -----------------------------------------------
# Use common testcase Makefile
# -----------------------------------------------
include ../test_base.mk
