# This Makefile provides generic instructions for executing the regio
# tool to elaborate regmap structures from yaml specifications and
# autogenerate associated RTL.
#
# Usage: this Makefile is used by including it at the end of a 'parent' Makefile,
#        where the parent can call the targets defined here.
#
# Note: Assumes the following path variables have been defined:
#           - SCRIPTS_ROOT (location of common script library)
#           - REGIO_ROOT (location of the regio tool)
#           - LIB_ROOT (location of library root dir)
#           - LIB_OUTPUT_ROOT (location of library output root dir)
# ----------------------------------------------------
__COMPONENT_BASE_NAME = $(subst .,_,$(COMPONENT_BASE))

# ----------------------------------------------------
# Paths
# ----------------------------------------------------
REGIO_YAML_INC_DIR ?= $(LIB_ROOT)

REGIO_TEMPLATES_DIR ?= $(LIB_ROOT)/src/reg/regio-templates

REGIO_COMPONENT_ROOT := $(LIB_OUTPUT_ROOT)/$(COMPONENT_ROOT_PATH)

REGIO_RTL_OUTPUT_DIR := $(COMPONENT_OUT_PATH)/rtl
REGIO_RTL_SRC_OUTPUT_DIR := $(REGIO_RTL_OUTPUT_DIR)/src
REGIO_RTL_INC_OUTPUT_DIR := $(REGIO_RTL_OUTPUT_DIR)/include

REGIO_VERIF_OUTPUT_DIR := $(COMPONENT_OUT_PATH)/verif
REGIO_VERIF_SRC_OUTPUT_DIR := $(REGIO_VERIF_OUTPUT_DIR)/src
REGIO_VERIF_INC_OUTPUT_DIR := $(REGIO_VERIF_OUTPUT_DIR)/include

REGIO_VERIF_HEADERS_OUTPUT_DIR = $(REGIO_VERIF_INC_OUTPUT_DIR)
REGIO_VERIF_PACKAGE_OUTPUT_DIR = $(REGIO_VERIF_SRC_OUTPUT_DIR)

REGIO_IR_OUTPUT_DIR = $(COMPONENT_OUT_PATH)/ir

# ----------------------------------------------------
# Sim objects
# ----------------------------------------------------
REGIO_RTL_SIM_OBJ = $(REGIO_RTL_OUTPUT_DIR)/$(SIMLIB_DIRNAME)/$(COMPONENT_NAME)__rtl.rlx
REGIO_VERIF_SIM_OBJ = $(REGIO_VERIF_OUTPUT_DIR)/$(SIMLIB_DIRNAME)/$(COMPONENT_NAME)__verif.rlx

# ----------------------------------------------------
# regio yaml source (provided by parent Makefile)
# ----------------------------------------------------
REG_BLOCK_YAML ?=
REG_DECODER_YAML ?=
REG_TOP_YAML ?=

REG_BLOCK_OBJS = $(REG_BLOCK_YAML:%.yaml=$(REGIO_RTL_SRC_OUTPUT_DIR)/%_reg_blk.sv)
REG_BLOCK_PKGS = $(REG_BLOCK_YAML:%.yaml=$(REGIO_RTL_SRC_OUTPUT_DIR)/%_reg_pkg.sv)
REG_DECODER_OBJS = $(REG_DECODER_YAML:%.yaml=$(REGIO_RTL_SRC_OUTPUT_DIR)/%.sv)

REG_VERIF_HEADER_OBJS = $(REG_BLOCK_YAML:%.yaml=$(REGIO_VERIF_HEADERS_OUTPUT_DIR)/%_reg_blk_agent.svh)
REG_VERIF_PACKAGE_OBJ = $(REGIO_VERIF_PACKAGE_OUTPUT_DIR)/$(__COMPONENT_BASE_NAME)_reg_verif_pkg.sv

REG_BLOCK_IR_OBJS = $(REG_BLOCK_YAML:%.yaml=$(REGIO_IR_OUTPUT_DIR)/%-ir.yaml)
REG_DECODER_IR_OBJS = $(REG_DECODER_YAML:%.yaml=$(REGIO_IR_OUTPUT_DIR)/%-ir.yaml)
REG_TOP_IR_OBJS = $(REG_TOP_YAML:%.yaml=$(REGIO_IR_OUTPUT_DIR)/%-ir.yaml)

# ----------------------------------------------------
# Options
# ----------------------------------------------------
# (full option list, including defaults)
REGIO_ELABORATE_DEFAULT_OPTS = -i $(REGIO_YAML_INC_DIR)
REGIO_GENERATE_SRC_DEFAULT_OPTS =  -t $(REGIO_TEMPLATES_DIR) -o $(REGIO_RTL_SRC_OUTPUT_DIR) -g sv
REGIO_GENERATE_HEADERS_DEFAULT_OPTS = -t $(REGIO_TEMPLATES_DIR) -o $(REGIO_VERIF_OUTPUT_DIR)/include -g svh -p $(__COMPONENT_BASE_NAME)_
REGIO_FLATTEN_DEFAULT_OPTS = -i $(REGIO_YAML_INC_DIR)

# (from parent Makefile)
REGIO_ELABORATE_OPTS ?=
REGIO_GENERATE_OPTS ?=

# ----------------------------------------------------
# Commands
# ----------------------------------------------------
REGIO_ELABORATE_CMD := $(REGIO_ROOT)/regio-elaborate $(REGIO_ELABORATE_DEFAULT_OPTS) $(REGIO_ELABORATE_OPTS)
REGIO_GENERATE_SRC_CMD := $(REGIO_ROOT)/regio-generate $(REGIO_GENERATE_SRC_DEFAULT_OPTS) $(REGIO_GENERATE_OPTS)
REGIO_GENERATE_HEADERS_CMD := $(REGIO_ROOT)/regio-generate $(REGIO_GENERATE_HEADERS_DEFAULT_OPTS) $(REGIO_GENERATE_OPTS)
REGIO_FLATTEN_CMD = $(REGIO_ROOT)/regio-flatten $(REGIO_FLATTEN_DEFAULT_OPTS)

# ----------------------------------------------------
# Targets
# ----------------------------------------------------
_reg: _reg_ir _reg_rtl _reg_verif

_reg_ir: $(REG_BLOCK_IR_OBJS) $(REG_DECODER_IR_OBJS) $(REG_TOP_IR_OBJS)

_reg_rtl: $(REG_BLOCK_OBJS) $(REG_DECODER_OBJS)

_reg_verif: $(REG_VERIF_PACKAGE_OBJ)

_reg_clean: _reg_compile_clean
	@-rm -rf $(COMPONENT_OUT_PATH)
	@-rm -f $(REGIO_COMPONENT_ROOT)/config.mk
	@[ ! -d $(LIB_OUTPUT_ROOT) ] || find $(LIB_OUTPUT_ROOT) -type d -empty -delete 2>/dev/null

$(REGIO_RTL_SRC_OUTPUT_DIR)/%_reg_blk.sv: %.yaml | $(REGIO_RTL_SRC_OUTPUT_DIR)
	@echo -n "Generating RTL for: $*.yaml ... "
	@$(REGIO_ELABORATE_CMD) -f block $*.yaml | $(REGIO_GENERATE_SRC_CMD) -f block -
	@echo "Done."

$(REGIO_RTL_SRC_OUTPUT_DIR)/%_decoder.sv: %_decoder.yaml | $(REGIO_RTL_SRC_OUTPUT_DIR)
	@echo -n "Generating RTL for: $*_decoder.yaml ... "
	@$(REGIO_ELABORATE_CMD) -f decoder $*_decoder.yaml | $(REGIO_GENERATE_SRC_CMD) -f decoder -
	@echo "Done."

$(REGIO_VERIF_HEADERS_OUTPUT_DIR)/%_reg_blk_agent.svh: %.yaml | $(REGIO_VERIF_HEADERS_OUTPUT_DIR)
	@echo -n "Generating verification headers for: $*.yaml ... "
	@$(REGIO_ELABORATE_CMD) -f block $*.yaml | $(REGIO_GENERATE_HEADERS_CMD) -f block -
	@echo "Done."

$(REG_VERIF_PACKAGE_OBJ): $(REG_VERIF_HEADER_OBJS) | $(REGIO_VERIF_PACKAGE_OUTPUT_DIR)
	@echo -n "Generating verification header manifest package for: $(__COMPONENT_BASE_NAME) library ..."
	@echo "//------------------------------------------------------------------------------" > $(REG_VERIF_PACKAGE_OBJ)
	@echo "// Verification header file manifest for $(__COMPONENT_BASE_NAME) register blocks." >> $(REG_VERIF_PACKAGE_OBJ)
	@echo "//" >> $(REG_VERIF_PACKAGE_OBJ)
	@echo "// NOTE: This file is autogenerated. DO NOT EDIT." >> $(REG_VERIF_PACKAGE_OBJ)
	@echo "//------------------------------------------------------------------------------" >> $(REG_VERIF_PACKAGE_OBJ)
	@echo "" >> $(REG_VERIF_PACKAGE_OBJ)
	@echo "package $(__COMPONENT_BASE_NAME)_reg_verif_pkg;" >> $(REG_VERIF_PACKAGE_OBJ)
	@echo $(foreach header_file,$(notdir $(REG_VERIF_HEADER_OBJS)),'\n`include "$(header_file)"') >> $(REG_VERIF_PACKAGE_OBJ)
	@echo "" >> $(REG_VERIF_PACKAGE_OBJ)
	@echo "endpackage : $(__COMPONENT_BASE_NAME)_reg_verif_pkg" >> $(REG_VERIF_PACKAGE_OBJ)
	@echo "Done."

$(REGIO_IR_OUTPUT_DIR)/%-ir.yaml: %.yaml | $(REGIO_IR_OUTPUT_DIR)
	@echo -n "Generating (flattened) IR for: $< ... "
	@$(REGIO_FLATTEN_CMD) -o $@ $<
	@echo "Done."

.PHONY: _reg _reg_rtl _reg_verif _reg_ir _reg_clean

$(REGIO_COMPONENT_ROOT)/config.mk:
	@mkdir -p $(REGIO_COMPONENT_ROOT)
	@echo '# ******** AUTOGENERATED FILE (DO NOT EDIT) ********'| cat - $(SCRIPTS_ROOT)/Makefiles/templates/component_config.mk > $(REGIO_COMPONENT_ROOT)/config.mk
	@sed -i 's;SRC_ROOT\s*\:\?=.*;SRC_ROOT := $(SRC_ROOT);' $(REGIO_COMPONENT_ROOT)/config.mk

$(REGIO_RTL_OUTPUT_DIR): $(REGIO_COMPONENT_ROOT)/config.mk
	@mkdir -p $(REGIO_RTL_OUTPUT_DIR)
	@echo '# ******** AUTOGENERATED FILE (DO NOT EDIT) ********'| cat - $(SCRIPTS_ROOT)/Makefiles/templates/component_rtl.mk > $(REGIO_RTL_OUTPUT_DIR)/Makefile
	@sed -i 's;COMPONENT_ROOT\s*\:\?=\s*..;COMPONENT_ROOT := $(REGIO_COMPONENT_ROOT);' $(REGIO_RTL_OUTPUT_DIR)/Makefile
	@sed -i 's/SUBCOMPONENTS\s*=/SUBCOMPONENTS = \\\n    reg.rtl$(if $(COMMON_LIB_NAME),$(lib_separator)$(COMMON_LIB_NAME),)\n/' $(REGIO_RTL_OUTPUT_DIR)/Makefile

$(REGIO_RTL_SRC_OUTPUT_DIR): | $(REGIO_RTL_OUTPUT_DIR)
	@mkdir -p $(REGIO_RTL_SRC_OUTPUT_DIR)

$(REGIO_RTL_INC_OUTPUT_DIR): | $(REGIO_RTL_OUTPUT_DIR)
	@mkdir -p $(REGIO_RTL_INC_OUTPUT_DIR)

$(REGIO_VERIF_OUTPUT_DIR): $(REGIO_COMPONENT_ROOT)/config.mk
	@mkdir -p $(REGIO_VERIF_OUTPUT_DIR)
	@echo '# ******** AUTOGENERATED FILE (DO NOT EDIT) ********'| cat - $(SCRIPTS_ROOT)/Makefiles/templates/component_verif.mk > $(REGIO_VERIF_OUTPUT_DIR)/Makefile
	@sed -i 's;COMPONENT_ROOT\s*\:\?=\s*..;COMPONENT_ROOT := $(REGIO_COMPONENT_ROOT);' $(REGIO_VERIF_OUTPUT_DIR)/Makefile
	@sed -i 's/SUBCOMPONENTS\s*=/SUBCOMPONENTS = \\\n    reg.verif$(if $(COMMON_LIB_NAME),$(lib_separator)$(COMMON_LIB_NAME),)\n/' $(REGIO_VERIF_OUTPUT_DIR)/Makefile
	@sed -i 's;EXT_LIBS\s*=;EXT_LIBS = $(COMPONENT_NAME)__rtl=$(COMPONENT_OUT_PATH)/rtl/lib;' $(REGIO_VERIF_OUTPUT_DIR)/Makefile

$(REGIO_VERIF_HEADERS_OUTPUT_DIR): | $(REGIO_VERIF_OUTPUT_DIR)
	@mkdir -p $(REGIO_VERIF_HEADERS_OUTPUT_DIR)

$(REGIO_VERIF_PACKAGE_OUTPUT_DIR): | $(REGIO_VERIF_OUTPUT_DIR)
	@mkdir -p $(REGIO_VERIF_PACKAGE_OUTPUT_DIR)

$(REGIO_IR_OUTPUT_DIR):
	@mkdir -p $@

_reg_compile: $(REGIO_RTL_SIM_OBJ) $(REGIO_VERIF_SIM_OBJ)

_reg_synth: reg
	@$(MAKE) -s -C $(REGIO_RTL_OUTPUT_DIR) synth

$(REGIO_RTL_SIM_OBJ): reg | $(REGIO_RTL_OUTPUT_DIR)
	@$(MAKE) -s -C $(REGIO_RTL_OUTPUT_DIR) compile

$(REGIO_VERIF_SIM_OBJ): reg | $(REGIO_VERIF_OUTPUT_DIR)
	@$(MAKE) -s -C $(REGIO_VERIF_OUTPUT_DIR) compile

_reg_compile_clean:
	@[ ! -f $(REGIO_RTL_OUTPUT_DIR)/Makefile ] || $(MAKE) -s -C $(REGIO_RTL_OUTPUT_DIR) clean
	@[ ! -f $(REGIO_VERIF_OUTPUT_DIR)/Makefile ] || $(MAKE) -s -C $(REGIO_VERIF_OUTPUT_DIR) clean

.PHONY: _reg_compile _reg_synth _reg_compile_clean

# Display component configuration
_reg_config_info:
	@echo "------------------------------------------------------"
	@echo "Regio configuration"
	@echo "------------------------------------------------------"
	@echo "REGIO_TEMPLATES_DIR : $(REGIO_TEMPLATES_DIR)"
	@echo "REGIO_YAML_INC_DIR  : $(REGIO_YAML_INC_DIR)"
	@echo "REG_BLOCK_YAML      :"
	@for blockyaml in $(REG_BLOCK_YAML); do \
		echo "\t$$blockyaml"; \
	done
	@echo "REG_DECODER_YAML    :"
	@for decoderyaml in $(REG_DECODER_YAML); do \
		echo "\t$$decoderyaml"; \
	done
	@echo "REGIO_IR_OUTPUT_DIR    : $(REGIO_IR_OUTPUT_DIR)"
	@echo "REGIO_RTL_OUTPUT_DIR   : $(REGIO_RTL_OUTPUT_DIR)"
	@echo "REGIO_VERIF_OUTPUT_DIR : $(REGIO_VERIF_OUTPUT_DIR)"

_reg_info: _reg_config_info .component_info

.PHONY: _reg_config_info _reg_info
