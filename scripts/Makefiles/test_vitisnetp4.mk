# ----------------------------------------------------
# Configure VitisNetP4 DPI-C driver
# ----------------------------------------------------
VITISNETP4_DRV_DPI_LIB = vitisnetp4_drv_dpi
VITISNETP4_DRV_DPI_FILE = $(shell find $(XILINX_VIVADO)/data/ip/xilinx/vitis_net_p4* -name "$(VITISNETP4_DRV_DPI_LIB).so")
VITISNETP4_DRV_DPI_DIR = $(dir $(VITISNETP4_DRV_DPI_FILE))

# ----------------------------------------------------
# Options
# ----------------------------------------------------
ELAB_OPTS +=--sv_root $(VITISNETP4_DRV_DPI_DIR) --sv_lib $(VITISNETP4_DRV_DPI_LIB)
