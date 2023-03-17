#!/bin/sh
# ******************************************************************************
#
# File: clean_ip.sh
#
# Description:
#
#   This script cleans up backup Makefiles in an existing IP library, e.g. after
#   executing update_ip.sh.
#
# ******************************************************************************

# Recover scripts directory path
SCRIPT_PATH=`dirname $0`
SCRIPTS_ROOT=`realpath ${SCRIPT_PATH}`

# IP name is provided as the first argument
IP_NAME_ARG=$1
shift

IP_DIR=`dirname ${IP_NAME_ARG}`

find ${IP_DIR} -type f -name 'Makefile.bak' -exec rm {} \;
exit 0
