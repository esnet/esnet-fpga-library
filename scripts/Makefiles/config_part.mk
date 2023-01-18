# -----------------------------------------------
# Part config Makefile snippet
#
#  Provides standardized configuration of device/board properties.
#
#  Expected to be included in a parent Makefile,
#  where the following variables are defined:
#
#  CFG_ROOT - path to configuration directory.
# -----------------------------------------------

CFG_FILE = $(CFG_ROOT)/part.mk

# Initialize variables
BOARD_REPO ?= empty
PART ?= empty
BOARD_PART ?= empty

# Check for overrides; allows null values to be specified
_config_done = false
ifneq ($(BOARD_REPO),empty)
_config_done = true
endif
ifneq ($(PART),empty)
_config_done = true
endif
ifneq ($(BOARD_PART),empty)
_config_done = true
endif

#_config_done = $(or $(SET_BOARD_REPO), $(SET_PART), $(SET_BOARD_PART))

_config_board_repo = @echo "Setting board repo to '$(BOARD_REPO)'"; \
                     $(shell sed -i s:\ *BOARD_REPO.*:BOARD_REPO\ \=\ $(BOARD_REPO):g $(CFG_FILE))
_config_part = @echo "Setting part to '$(PART)'"; \
               $(shell sed -i s/^\ *PART\ .*/PART\ \=\ $(PART)/g $(CFG_FILE))
_config_board_part = @echo "Setting board part to '$(BOARD_PART)'"; \
                     $(shell sed -i s/\ *BOARD_PART.*/BOARD_PART\ \=\ $(BOARD_PART)/g $(CFG_FILE))

_print_help = @echo "Part configuration";\
			  echo "  - specify physical board/device targets for project";\
			  echo "";\
              echo "Usage:";\
              echo "  make config [PART=<part>] [BOARD_PART=<board_part>] [BOARD_REPO=<path_to_board_files>]"; \
              echo "Examples:"; \
              echo "  make config PART=xcu280-fsvh2892-2L-e"; \
              echo "  make config BOARD_REPO=./board_files/Xilinx PART=xcu280-fsvh2892-2L-e"

_config_help:
	$(_print_help)

_config:
ifneq ($(BOARD_REPO),empty)
	$(_config_board_repo)
endif
ifneq ($(PART),empty)
	$(_config_part)
endif
ifneq ($(BOARD_PART),empty)
	$(_config_board_part)
endif
ifeq ($(_config_done),false)
	$(_print_help)
endif
