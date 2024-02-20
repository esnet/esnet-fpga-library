#!/bin/sh
# ******************************************************************************
#
# File: clean-component.sh
#
# Description:
#
#   This script cleans up backup Makefiles in an existing component library, e.g. after
#   executing update_component.sh.
#
# ******************************************************************************

# Recover scripts directory path
SCRIPT_PATH=`dirname $0`
SCRIPTS_ROOT=`realpath ${SCRIPT_PATH}`

# Component name is provided as the first argument
COMPONENT_NAME_ARG=$1
shift

COMPONENT_DIR=`dirname ${COMPONENT_NAME_ARG}`

find ${COMPONENT_DIR} -type f -name 'Makefile.bak' -exec rm {} \;
find ${COMPONENT_DIR} -type f -name 'test_base.mk.bak' -exec rm {} \;
exit 0
