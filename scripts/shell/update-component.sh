#!/bin/sh
# ******************************************************************************
#
# File: update-component.sh
#
# Description:
#
#   This script updates the Makefiles in an existing component library, including
#   replacement of Makefiles at the component, subcomponent, and test levels.
#
#   Note: this is equivalent to 'initializing' the Makefiles for the component library,
#   such that they are set up as they would be after running init-component.sh.
#
#   *** NO CUSTOMIZATION IS PRESERVED ***
#
# ******************************************************************************

# Recover scripts directory path
SCRIPT_PATH=`dirname $0`
SCRIPTS_ROOT=`realpath ${SCRIPT_PATH}/..`
TEMPLATES_PATH=${SCRIPTS_ROOT}/Makefiles/templates

# Component name is provided as the first argument
COMPONENT_NAME_ARG=$1
shift

COMPONENT_DIR=`basename ${COMPONENT_NAME_ARG}`

COMPONENT_NAME="`echo ${IP_NAME_ARG} | tr '[:upper:]' '[:lower:]'`"

if [ -d ${COMPONENT_NAME_ARG} ]; then
    echo "Updating ${COMIPONENT_NAME} component at ${COMPONENT_NAME_ARG}..."
    # Process IP root directory
    cd ${COMPONENT_NAME_ARG}
    cmp -s ${TEMPLATES_PATH}/component.mk Makefile || \
        cp --backup=simple --suffix=.bak ${TEMPLATES_PATH}/component.mk Makefile
    cmp -s ${TEMPLATES_PATH}/component_config.mk config.mk || \
        cp --backup=simple --suffix=.bak ${TEMPLATES_PATH}/component_config.mk config.mk
    SUBDIRS=`find .  -mindepth 1 -maxdepth 1 -type d`
    # Process subdirectories
    for subdir in ${SUBDIRS}; do
        cd ${subdir}
        # Tests
        if [ "`basename ${subdir}`" = "tests" ]; then
            cmp -s ${TEMPLATES_PATH}/test_svunit.mk test_base.mk || \
                cp --backup=simple --suffix=.bak ${TEMPLATES_PATH}/test_base_svunit.mk test_base.mk
            TESTDIRS=`find . -mindepth 1 -maxdepth 1 -type d`
            for testdir in ${TESTDIRS}; do
                cd ${testdir}
                cmp -s ${TEMPLATES_PATH}/test.mk Makefile || \
                    cp --backup=simple --suffix=.bak ${TEMPLATES_PATH}/test.mk Makefile
                if [ "`basename ${testdir}`" = "regression" ]; then
                    # Configure regression parameters
                    sed -i 's/REGRESSION = 0/REGRESSION = 1/g' Makefile
                fi
                cd ..
            done
        elif [ "`basename ${subdir}`" = "rtl" ]; then
            cmp -s ${TEMPLATES_PATH}/component_rtl.mk Makefile || \
                cp --backup=simple --suffix=.bak ${TEMPLATES_PATH}/component_rtl.mk Makefile
        elif [ "`basename ${subdir}`" = "ip" ]; then
            cmp -s ${TEMPLATES_PATH}/component_ip.mk Makefile || \
                cp --backup=simple --suffix=.bak ${TEMPLATES_PATH}/component_ip.mk Makefile
        elif [ "`basename ${subdir}`" = "verif" ]; then
            cmp -s ${TEMPLATES_PATH}/component_verif.mk Makefile || \
                cp --backup=simple --suffix=.bak ${TEMPLATES_PATH}/component_verif.mk Makefile
        elif [ "`basename ${subdir}`" = "tb" ]; then
            cmp -s ${TEMPLATES_PATH}/component_verif.mk Makefile || \
                cp --backup=simple --suffix=.bak ${TEMPLATES_PATH}/component_verif.mk Makefile
        elif [ "`basename ${subdir}`" = "regio" ]; then
            cmp -s ${TEMPLATES_PATH}/component_regio.mk Makefile || \
                cp --backup=simple --suffix=.bak ${TEMPLATES_PATH}/component_regio.mk Makefile
        fi
        cd ..
    done
else
    echo "ERROR: Component directory $COMPONENT_NAME not found."
    exit 1
fi
echo "Done."
exit 0
