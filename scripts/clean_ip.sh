#!/bin/sh
# ==============================================================================
#  NOTICE: This computer software was prepared by The Regents of the
#  University of California through Lawrence Berkeley National Laboratory
#  and Jonathan Sewter hereinafter the Contractor, under Contract No.
#  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
#  computer software are reserved by DOE on behalf of the United States
#  Government and the Contractor as provided in the Contract. You are
#  authorized to use this computer software for Governmental purposes but it
#  is not to be released or distributed to the public.
#
#  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
#  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
#
#  This notice including this sentence must appear on any copies of this
#  computer software.
# ==============================================================================

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
