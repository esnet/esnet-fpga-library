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
# File: init_ip.sh
#
# Description:
#
#   This script initializes a new IP library, including standard directory
#   structure and Make infrastructure.
#
# ******************************************************************************

# IP name is provided as the first argument
IP_NAME_ARG=$1
shift

# Convert to lowercase
IP_NAME="`echo ${IP_NAME_ARG} | tr '[:upper:]' '[:lower:]'`"

# IP directory
IP_DIR=${IP_NAME}

# Component list is provided in remaining arguments.
# Note: 'rtl' component is created by default
# e.g. 'init_ip.sh IP_NAME tb verif' initializes IP 'IP_NAME' with
#      subdirectories 'rtl', 'tb' and 'verif'
COMPONENTS_ARGS="rtl regio verif $@"
# (Uniquify component list - guards against unintentional duplication of rtl component)
COMPONENTS_LINES="`echo ${COMPONENTS_ARGS} | tr ' ' '\n' | sort -u`"
# (List, separated by spaces)
COMPONENTS="`echo ${COMPONENTS_LINES} | tr '\n' ' '`"

# Recover scripts directory path
__SCRIPTS_ROOT="`dirname $0`"
SCRIPTS_ROOT="`realpath ${__SCRIPTS_ROOT}`"
SVUNIT_ROOT=${SCRIPTS_ROOT}/../tools/svunit

COMPONENT_SUBDIRS="src include"

TEST_DIR="tests"
TEST_SUBDIRS="$IP_NAME regression"

if (mkdir $IP_DIR); then
    echo "Initializing library for $IP_NAME_ARG IP..."
    # -----------------------
    # Root directory setup
    # -----------------------
    cd $IP_DIR
    # Copy 'root' Makefile
    cp ${SCRIPTS_ROOT}/Makefiles/ip.mk Makefile
    # Copy path setup Makefile snippet
    cp ${SCRIPTS_ROOT}/Makefiles/ip_config.mk config.mk
    # Copy README and customize
    cp ${SCRIPTS_ROOT}/env/ip_README.md README.md
    sed -i "s/MY_IP_NAME/${IP_NAME}/g" README.md
    # -----------------------
    # Source directory setup
    # -----------------------
    mkdir ${COMPONENTS}
    for subdir in ${COMPONENTS}
    do
        cd $subdir
        if [ "${subdir}" = "regio" ]; then
            # Create reg-specific component-level compilation Makefile
            cp ${SCRIPTS_ROOT}/Makefiles/component_regio.mk Makefile
            sed -i "s/MY_IP_NAME/${IP_NAME}/g" Makefile
            # Create example reg block yaml description
            cp ${SCRIPTS_ROOT}/env/reg_blk_example.yaml ${IP_NAME}.yaml
            sed -i "s/MY_IP_NAME/${IP_NAME}/g" ${IP_NAME}.yaml
        else
            mkdir ${COMPONENT_SUBDIRS}
            # Create component-level compilation Makefile
            cp ${SCRIPTS_ROOT}/Makefiles/component.mk  Makefile
            # Create 'dummy' module
            if [ "${subdir}" = "rtl" ]; then
                MODULE_NAME=$IP_NAME
            else
                MODULE_NAME=${IP_NAME}_${subdir}
            fi
            echo "module ${MODULE_NAME} (\n    input dummy\n);\nendmodule" >> src/${MODULE_NAME}.sv
        fi
        cd ..
    done
    # -----------------------
    # Test directory setup
    # -----------------------
    mkdir $TEST_DIR
    cd $TEST_DIR
    for subdir in $TEST_SUBDIRS
    do
        mkdir $subdir
        cd $subdir
        # Create test Makefile and customize dependencies
        cp ${SCRIPTS_ROOT}/Makefiles/test_svunit.mk  Makefile
        sed -i "s/^COMPONENTS\s*=\s*$/&${COMPONENTS}/g" Makefile
        if [ "${subdir}" = "${IP_NAME}" ]; then
            # Autogenerate unit test prototype for IP
            ${SVUNIT_ROOT}/bin/create_unit_test.pl ../../rtl/src/${IP_NAME}.sv
            sed -i "/^\`include.*${IP_NAME}.*$/d" ${IP_NAME}_unit_test.sv
        elif [ "${subdir}" = "regression" ]; then
            # Configure regression parameters
            sed -i 's/REGRESSION ?= 0/REGRESSION = 1/g' Makefile
        fi
        cd ..
    done
    echo "Done."
else
    echo "ERROR: IP directory $IP_NAME already exists."
    exit 1
fi
exit 0
