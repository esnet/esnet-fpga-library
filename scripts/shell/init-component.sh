#!/bin/sh
# ******************************************************************************
#
# File: init-component.sh
#
# Description:
#
#   This script initializes a new component library, including standard directory
#   structure and Make infrastructure.
#
# ******************************************************************************

# Component name is provided as the first argument
COMPONENT_NAME_ARG=$1
shift

# Convert to lowercase
COMPONENT_NAME="`echo ${COMPONENT_NAME_ARG} | tr '[:upper:]' '[:lower:]'`"

# Component directory
COMPONENT_DIR=${COMPONENT_NAME}

# Component list is provided in remaining arguments.
# Note: 'rtl' component is created by default
# e.g. 'init_component.sh COMPONENT_NAME regio verif' initializes component 'COMPONENT_NAME' with
#      subdirectories 'rtl', 'regio' and 'verif'
SUBCOMPONENTS_ARGS="rtl $@"
# (Uniquify component list - guards against unintentional duplication of rtl component)
SUBCOMPONENTS_LINES="`echo ${SUBCOMPONENTS_ARGS} | tr ' ' '\n' | sort -u`"
# (List, separated by spaces)
SUBCOMPONENTS="`echo ${SUBCOMPONENTS_LINES} | tr '\n' ' '`"

# Recover scripts directory path
__SCRIPTS_ROOT="`dirname $0`/.."
SCRIPTS_ROOT="`realpath ${__SCRIPTS_ROOT}`"
TEMPLATES_PATH=${SCRIPTS_ROOT}/Makefiles/templates
SVUNIT_ROOT=${SCRIPTS_ROOT}/../tools/svunit

SUBCOMPONENT_SUBDIRS="src include"

TEST_DIR="tests"
TEST_SUBDIRS="$COMPONENT_NAME regression"

if (mkdir $COMPONENT_DIR); then
    echo "Initializing library for $COMPONENT_NAME_ARG IP..."
    # -----------------------
    # Root directory setup
    # -----------------------
    cd $COMPONENT_DIR
    # Copy 'root' Makefile
    cp ${TEMPLATES_PATH}/component.mk Makefile
    # Copy config Makefile snippet
    cp ${TEMPLATES_PATH}/component_config.mk config.mk
    # Copy README and customize
    cp ${SCRIPTS_ROOT}/env/component_README.md README.md
    sed -i "s/MY_COMPONENT_NAME/${COMPONENT_NAME}/g" README.md
    # -----------------------
    # Source directory setup
    # -----------------------
    mkdir ${SUBCOMPONENTS}
    for subdir in ${SUBCOMPONENTS}
    do
        cd $subdir
        if [ "${subdir}" = "regio" ]; then
            # Create reg-specific component-level compilation Makefile
            cp ${TEMPLATES_PATH}/component_regio.mk Makefile
            # Create example reg block yaml description
            cp ${SCRIPTS_ROOT}/env/reg_blk_example.yaml ${COMPONENT_NAME}.yaml
            sed -i "s/MY_COMPONENT_NAME/${COMPONENT_NAME}/g" ${COMPONENT_NAME}.yaml
        else
            mkdir ${SUBCOMPONENT_SUBDIRS}
            # Create component-level compilation Makefile; also create 'dummy' module
            if [ "${subdir}" = "ip" ]; then
                cp ${TEMPLATES_PATH}/component_ip.mk  Makefile
            else
                if [ "${subdir}" = "rtl" ]; then
                    cp ${TEMPLATES_PATH}/component_rtl.mk  Makefile
                    MODULE_NAME=${COMPONENT_NAME}
                elif [ "${subdir}" = "verif" ]; then
                    cp ${TEMPLATES_PATH}/component_verif.mk  Makefile
                    MODULE_NAME=${COMPONENT_NAME}_verif
                elif [ "${subdir}" = "tb" ]; then
                    cp ${TEMPLATES_PATH}/component_verif.mk  Makefile
                    MODULE_NAME=${COMPONENT_NAME}_tb
                fi
                echo "module ${MODULE_NAME} (\n    input dummy\n);\nendmodule" >> src/${MODULE_NAME}.sv
            fi
        fi
        cd ..
    done
    # -----------------------
    # Test directory setup
    # -----------------------
    mkdir $TEST_DIR
    cd $TEST_DIR
    cp ${TEMPLATES_PATH}/test_base_svunit.mk test_base.mk
    for subdir in $TEST_SUBDIRS
    do
        mkdir $subdir
        cd $subdir
        # Create test Makefile and customize dependencies
        cp ${TEMPLATES_PATH}/test.mk  Makefile
        if [ "${subdir}" = "${COMPONENT_NAME}" ]; then
            # Autogenerate unit test prototype for IP
            ${SVUNIT_ROOT}/bin/create_unit_test.pl ../../rtl/src/${COMPONENT_NAME}.sv
            sed -i "/^\`include.*${COMPONENT_NAME}.*$/d" ${COMPONENT_NAME}_unit_test.sv
        elif [ "${subdir}" = "regression" ]; then
            # Configure regression parameters
            sed -i 's/REGRESSION = 0/REGRESSION = 1/g' Makefile
        fi
        cd ..
    done
    echo "Done."
else
    echo "ERROR: IP directory $COMPONENT_NAME already exists."
    exit 1
fi
exit 0
