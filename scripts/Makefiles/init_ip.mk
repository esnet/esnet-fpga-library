# Path to 'verilog' project root
PROJ_ROOT = $(abspath $(shell pwd)/..)

# Source common project paths
include $(PROJ_ROOT)/paths.mk

HELP_STRING :="\n"
HELP_STRING +="IP initialization\n"
HELP_STRING +="-----------------\n"
HELP_STRING +="To initalize an IP libary with name 'IP_NAME', call target init_ with IP_NAME, e.g.:\n"
HELP_STRING +="\n"
HELP_STRING +="\tmake init_IP_NAME\n"
HELP_STRING +="\n"
HELP_STRING +="By default, the IP library is created with 'rtl' component only. To create additional\n"
HELP_STRING +="components at time of creation, set COMPONENTS="component_names" when executing target. e.g.:\n"
HELP_STRING +="\n"
HELP_STRING +="\tmake init_IP_NAME COMPONENTS='tb verif'\n"
HELP_STRING +="\n"
HELP_STRING +="creates an IP library with name 'IP_NAME' comprised of rtl, tb and verif components."
HELP_STRING +="\n"

dummy:
	@echo "No implicit Make target. This Makefile can be used to initialize IP libraries. See description below."
	@echo $(HELP_STRING)

COMPONENTS ?=

# Initialize an IP library with specified name, i.e. init_IP_NAME creates
# library IP_NAME, including standard directory structure and Make infrastructure.
init_%:
	@$(SCRIPTS_ROOT)/init_ip.sh $* $(COMPONENTS)

# Intercept bad target
init_:
	@echo "No IP name specified."
	@echo $(HELP_STRING)

help:
	@echo $(HELP_STRING)
