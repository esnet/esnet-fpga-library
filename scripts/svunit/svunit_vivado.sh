#!/bin/sh
# ******************************************************************************
#
# File: svunit_vivado.sh
#
# Description:
#
#   This is a helper script that makes minor modifications to the shape of the
#   SVUnit build outputs so that they are compatible with the proprietary
#   ESnet compile/sim scripting infrastructure.
#
# ******************************************************************************

# Enhancement: Allow prefixing of files in source list to allow separate compile
#              and run directories.
# ----------------------------------------------
if [ $# -lt 1 ]; then TARGET_DIR=pwd
else                  TARGET_DIR=$1
fi

# Add ${TARGET_DIR} root to path of all references to files in current directory
sed -i "s:^\.:${TARGET_DIR}/&:" ${TARGET_DIR}/.svunit.f

# Add ${TARGET_DIR} to list of include directories
echo +incdir+${TARGET_DIR} >> ${TARGET_DIR}/.svunit.f

# Enhancement: Rename package files with _pkg suffix since these source files
#              are identified as packages and compiled first.
# ----------------------------------------------
# Create ephemeral copy of junit_xml package in run directory, including _pkg suffix
# (_pkg source files are identified as packages and compiled first)
cp ${SVUNIT_INSTALL}/svunit_base/junit-xml/junit_xml.sv ${TARGET_DIR}/junit_xml_pkg.sv

# Modify file list to refer to modified junit_xml
sed -i "s:^.*junit_xml.sv:${TARGET_DIR}/junit_xml_pkg.sv:g" ${TARGET_DIR}/.svunit.f

