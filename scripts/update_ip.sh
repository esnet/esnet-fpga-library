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
# File: update_ip.sh
#
# Description:
#
#   This script updates the Makefiles in an existing IP library, including
#   replacement of Makefiles at the IP, component, and test levels.
#
#   Note: this is equivalent to 'initializing' the Makefiles for the IP library,
#   such that they are set up as they would be after running init_ip.
#
#   *** NO CUSTOMIZATION IS PRESERVED ***
#
# ******************************************************************************

# Recover scripts directory path
SCRIPT_PATH=`dirname $0`
SCRIPTS_ROOT=`realpath ${SCRIPT_PATH}`

# IP name is provided as the first argument
IP_NAME_ARG=$1
shift

IP_DIR=`basename ${IP_NAME_ARG}`

IP_NAME="`echo ${IP_NAME_ARG} | tr '[:upper:]' '[:lower:]'`"

if [ -d ${IP_NAME_ARG} ]; then
    echo "Updating ${IP_NAME} IP at ${IP_NAME_ARG}..."
    # Process IP root directory
    cd ${IP_NAME_ARG}
    cp ${SCRIPTS_ROOT}/Makefiles/ip_root.mk Makefile
    if [ ! -e paths.mk ]; then
        cp ${SCRIPTS_ROOT}/Makefiles/ip_config.mk config.mk
    fi
    SUBDIRS=`find .  -mindepth 1 -maxdepth 1 -type d`
    # Find 'local' components
    COMPONENTS=""
    for subdir in ${SUBDIRS}; do
        if [ "`basename ${subdir}`" != "tests" ]; then
            if [ -e "${subdir}/Makefile" ]; then
                COMPONENTS="${COMPONENTS} `basename ${subdir}`"
            fi
        fi
    done
    # Process subdirectories
    for subdir in ${SUBDIRS}; do
        cd ${subdir}
        # Tests
        if [ "`basename ${subdir}`" = "tests" ]; then
            TESTDIRS=`find . -mindepth 1 -maxdepth 1 -type d`
            for testdir in ${TESTDIRS}; do
                cd ${testdir}
                cp --backup=simple --suffix=.bak ${SCRIPTS_ROOT}/Makefiles/test_svunit.mk Makefile
                sed -i "s/^COMPONENTS\s*=\s*$/&${COMPONENTS}/g" Makefile
                if [ "`basename ${testdir}`" = "regression" ]; then
                    # Configure regression parameters
                    sed -i 's/REGRESSION ?= 0/REGRESSION = 1/g' Makefile
                fi
                cd ..
            done
        else
            #Components
            if [ -e Makefile ]; then
                cp --backup=simple --suffix=.bak ${SCRIPTS_ROOT}/Makefiles/component.mk Makefile
            fi
        fi
        cd ..
    done
else
    echo "ERROR: IP directory $IP_NAME not found."
    exit 1
fi
echo "Done."
exit 0
