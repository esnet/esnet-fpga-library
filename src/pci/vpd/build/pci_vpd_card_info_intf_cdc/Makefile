COMPONENT_ROOT := ../../..
include $(COMPONENT_ROOT)/config.mk

TOP = pci_vpd_card_info_intf_cdc_wrapper
SUBCOMPONENTS = pci.vpd.rtl

all: opt validate
pre_synth: _pre_synth
synth: _build_core_synth
opt: _build_core_opt
validate: _build_core_validate
info: _build_core_info
clean: _build_clean
.PHONY: all pre_synth synth opt validate info clean

include $(SCRIPTS_ROOT)/Makefiles/vivado_build_core.mk
